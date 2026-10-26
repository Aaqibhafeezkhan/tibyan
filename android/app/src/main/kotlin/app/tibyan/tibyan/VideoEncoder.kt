package app.tibyan.tibyan

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * «مشاركة كمقطع فيديو»: the reel's encoder (`app.tibyan/video`). Frames
 * arrive as RGBA and go to an H.264 track (MediaCodec + MediaMuxer); at the
 * end the recitation's cut is decoded, faded, encoded as AAC and muxed with
 * the frames into one MP4. All on the device.
 */
class VideoEncoder(messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var job: Job? = null

    init {
        MethodChannel(messenger, "app.tibyan/video").setMethodCallHandler { call, result ->
            worker.execute {
                val reply: Result<Any?> = runCatching {
                    when (call.method) {
                        "available" -> true
                        "start" -> {
                            job?.cancel()
                            job = Job(
                                call.argument<String>("path")!!,
                                call.argument<Int>("width")!!,
                                call.argument<Int>("height")!!,
                                call.argument<Int>("fps")!!,
                            )
                            true
                        }
                        "frame" -> {
                            val j = job ?: error("no job")
                            j.append(call.argument<ByteArray>("rgba")!!, call.argument<Int>("repeat") ?: 1)
                            true
                        }
                        "finish" -> {
                            val j = job ?: error("no job")
                            job = null
                            j.finish(
                                call.argument<String>("audio"),
                                call.argument<Double>("audioStart") ?: 0.0,
                                call.argument<Double>("audioEnd") ?: 0.0,
                                call.argument<Double>("audioOffset") ?: 0.0,
                                call.argument<Double>("fadeIn") ?: 0.0,
                                call.argument<Double>("fadeOut") ?: 0.0,
                            )
                        }
                        "cancel" -> {
                            job?.cancel()
                            job = null
                            true
                        }
                        else -> throw NotImplementedError(call.method)
                    }
                }
                main.post {
                    reply.fold(
                        { result.success(it) },
                        {
                            if (it is NotImplementedError) result.notImplemented()
                            else result.error("video", it.toString(), null)
                        },
                    )
                }
            }
        }
    }

    private class Job(path: String, val width: Int, val height: Int, val fps: Int) {
        val out = File(path)
        val video = File(path.removeSuffix(".mp4") + ".video.mp4")
        val codec: MediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        val muxer: MediaMuxer
        var track = -1
        var frames = 0L
        val info = MediaCodec.BufferInfo()
        val y = ByteArray(width * height)
        val u = ByteArray((width / 2) * (height / 2))
        val v = ByteArray((width / 2) * (height / 2))

        init {
            out.delete()
            video.delete()
            val f = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
            f.setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            )
            f.setInteger(MediaFormat.KEY_BIT_RATE, width * height * 4)
            f.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            f.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
            codec.configure(f, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            muxer = MediaMuxer(video.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        }

        /** RGBA to YUV 4:2:0 (BT.601, limited range). */
        private fun convert(rgba: ByteArray) {
            val w2 = width / 2
            for (j in 0 until height) {
                var p = j * width * 4
                for (i in 0 until width) {
                    val r = rgba[p].toInt() and 255
                    val g = rgba[p + 1].toInt() and 255
                    val b = rgba[p + 2].toInt() and 255
                    y[j * width + i] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte()
                    if (j and 1 == 0 && i and 1 == 0) {
                        val k = (j / 2) * w2 + i / 2
                        u[k] = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte()
                        v[k] = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte()
                    }
                    p += 4
                }
            }
        }

        fun append(rgba: ByteArray, repeat: Int) {
            convert(rgba)
            repeat(max(1, repeat)) {
                var index: Int
                do {
                    index = codec.dequeueInputBuffer(10_000)
                    if (index < 0) drain(false)
                } while (index < 0)
                val image = codec.getInputImage(index)!!
                val planes = image.planes
                fill(planes[0].buffer, planes[0].rowStride, planes[0].pixelStride, y, width, height)
                fill(planes[1].buffer, planes[1].rowStride, planes[1].pixelStride, u, width / 2, height / 2)
                fill(planes[2].buffer, planes[2].rowStride, planes[2].pixelStride, v, width / 2, height / 2)
                codec.queueInputBuffer(index, 0, width * height * 3 / 2, frames * 1_000_000L / fps, 0)
                frames++
                drain(false)
            }
        }

        private fun fill(buf: ByteBuffer, rowStride: Int, pixelStride: Int, src: ByteArray, w: Int, h: Int) {
            for (j in 0 until h) {
                if (pixelStride == 1) {
                    buf.position(j * rowStride)
                    buf.put(src, j * w, w)
                } else {
                    for (i in 0 until w) buf.put(j * rowStride + i * pixelStride, src[j * w + i])
                }
            }
        }

        private fun drain(end: Boolean) {
            while (true) {
                val index = codec.dequeueOutputBuffer(info, if (end) 10_000 else 0)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!end) return
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                    }
                    index >= 0 -> {
                        val buf = codec.getOutputBuffer(index)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0 && track >= 0) muxer.writeSampleData(track, buf, info)
                        codec.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }

        fun cancel() {
            runCatching { codec.stop() }
            runCatching { codec.release() }
            runCatching { muxer.release() }
            video.delete()
            out.delete()
        }

        fun finish(audio: String?, start: Double, end: Double, offset: Double, fadeIn: Double, fadeOut: Double): String {
            var index: Int
            do {
                index = codec.dequeueInputBuffer(10_000)
                if (index < 0) drain(false)
            } while (index < 0)
            codec.queueInputBuffer(index, 0, 0, frames * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            drain(true)
            codec.stop()
            codec.release()
            muxer.stop()
            muxer.release()
            try {
                val aac = if (audio != null && end > start) {
                    encodeAac(decodeCut(audio, start, end, fadeIn, fadeOut), offset)
                } else null
                mux(aac)
            } finally {
                video.delete()
            }
            return out.path
        }

        private class Pcm(val samples: ShortArray, val rate: Int, val channels: Int)

        /** The cut [start, end) of the file as 16-bit PCM, faded in and out. */
        private fun decodeCut(path: String, start: Double, end: Double, fadeIn: Double, fadeOut: Double): Pcm {
            val ex = MediaExtractor()
            ex.setDataSource(path)
            val t = (0 until ex.trackCount).first {
                ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)!!.startsWith("audio/")
            }
            ex.selectTrack(t)
            val format = ex.getTrackFormat(t)
            val dec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            dec.configure(format, null, null, 0)
            dec.start()
            ex.seekTo((start * 1e6).toLong(), MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val out = java.io.ByteArrayOutputStream()
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var done = false
            while (!done) {
                if (!inputDone) {
                    val i = dec.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val n = ex.readSampleData(dec.getInputBuffer(i)!!, 0)
                        if (n < 0 || ex.sampleTime > (end * 1e6).toLong() + 200_000) {
                            dec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            dec.queueInputBuffer(i, 0, n, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val o = dec.dequeueOutputBuffer(info, 10_000)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    rate = dec.outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = dec.outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                } else if (o >= 0) {
                    val buf = dec.getOutputBuffer(o)!!.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                    val n = info.size / 2
                    val frames = n / channels
                    for (f in 0 until frames) {
                        val at = info.presentationTimeUs / 1e6 + f.toDouble() / rate
                        if (at < start || at >= end) continue
                        val gain = min(1.0, min(
                            if (fadeIn > 0) (at - start) / fadeIn else 1.0,
                            if (fadeOut > 0) (end - at) / fadeOut else 1.0,
                        ))
                        for (c in 0 until channels) {
                            val s = (buf.get(f * channels + c) * gain).roundToInt()
                            out.write(s and 255)
                            out.write((s shr 8) and 255)
                        }
                    }
                    dec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) done = true
                }
            }
            dec.stop()
            dec.release()
            ex.release()
            val bytes = out.toByteArray()
            val shorts = ShortArray(bytes.size / 2)
            ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(shorts)
            return Pcm(shorts, rate, channels)
        }

        private class Aac(val format: MediaFormat, val samples: List<Pair<ByteArray, MediaCodec.BufferInfo>>)

        /** [pcm] after [offset] seconds of silence, as AAC samples. */
        private fun encodeAac(pcm: Pcm, offset: Double): Aac {
            val silence = (offset * pcm.rate).toInt() * pcm.channels
            val total = silence + pcm.samples.size
            val f = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, pcm.rate, pcm.channels)
            f.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            f.setInteger(MediaFormat.KEY_BIT_RATE, 160_000)
            f.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            val enc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            enc.configure(f, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            enc.start()
            var format: MediaFormat? = null
            val samples = mutableListOf<Pair<ByteArray, MediaCodec.BufferInfo>>()
            val info = MediaCodec.BufferInfo()
            var fed = 0
            var inputDone = false
            var done = false
            while (!done) {
                if (!inputDone) {
                    val i = enc.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val buf = enc.getInputBuffer(i)!!.order(ByteOrder.LITTLE_ENDIAN)
                        buf.clear()
                        val n = min(buf.capacity() / 2, total - fed)
                        val pts = (fed / pcm.channels).toLong() * 1_000_000L / pcm.rate
                        if (n <= 0) {
                            enc.queueInputBuffer(i, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            val sb = buf.asShortBuffer()
                            for (k in 0 until n) {
                                val at = fed + k
                                sb.put(if (at < silence) 0 else pcm.samples[at - silence])
                            }
                            enc.queueInputBuffer(i, 0, n * 2, pts, 0)
                            fed += n
                        }
                    }
                }
                val o = enc.dequeueOutputBuffer(info, 10_000)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    format = enc.outputFormat
                } else if (o >= 0) {
                    val buf = enc.getOutputBuffer(o)!!
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && info.size > 0) {
                        val bytes = ByteArray(info.size)
                        buf.position(info.offset)
                        buf.get(bytes)
                        val copy = MediaCodec.BufferInfo()
                        copy.set(0, info.size, info.presentationTimeUs, info.flags)
                        samples.add(bytes to copy)
                    }
                    enc.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) done = true
                }
            }
            enc.stop()
            enc.release()
            return Aac(format ?: enc.outputFormat, samples)
        }

        private fun mux(aac: Aac?) {
            val ex = MediaExtractor()
            ex.setDataSource(video.path)
            ex.selectTrack(0)
            val m = MediaMuxer(out.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val vt = m.addTrack(ex.getTrackFormat(0))
            val at = aac?.let { m.addTrack(it.format) } ?: -1
            m.start()
            val buf = ByteBuffer.allocate(max(1 shl 20, width * height * 2))
            val info = MediaCodec.BufferInfo()
            val endUs = frames * 1_000_000L / fps
            while (true) {
                val n = ex.readSampleData(buf, 0)
                if (n < 0) break
                info.set(0, n, ex.sampleTime, ex.sampleFlags)
                m.writeSampleData(vt, buf, info)
                ex.advance()
            }
            aac?.samples?.forEach { (bytes, i) ->
                if (i.presentationTimeUs <= endUs) m.writeSampleData(at, ByteBuffer.wrap(bytes), i)
            }
            m.stop()
            m.release()
            ex.release()
        }
    }
}
