import AVFoundation
import Accelerate
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

/// «مشاركة كمقطع فيديو»: the reel's encoder (`app.tibyan/video`). Frames
/// arrive as RGBA from Flutter and go to an H.264 track (AVAssetWriter);
/// at the end the recitation's cut is laid under them with its fades and
/// the whole is written as an H.264/AAC MP4 (AVAssetExportSession). All on
/// the device, no other software.
final class VideoEncoderChannel {
  private static var channel: FlutterMethodChannel?
  private static let queue = DispatchQueue(label: "app.tibyan.video")
  private static var job: Job?
  private static var finishing: Job?

  static func attach(_ messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "app.tibyan/video", binaryMessenger: messenger)
    c.setMethodCallHandler { call, result in
      if call.method == "finish" { pendingFinish = result }
      let args = call.arguments as? [String: Any] ?? [:]
      queue.async {
        let reply: Any?
        do {
          reply = try handle(call.method, args)
        } catch {
          reply = FlutterError(code: "video", message: "\(error)", details: nil)
        }
        if call.method == "finish", reply == nil { return }  // replies later
        DispatchQueue.main.async { result(reply) }
      }
    }
    channel = c
  }

  private static var pendingFinish: FlutterResult?

  private static func handle(_ method: String, _ a: [String: Any]) throws -> Any? {
    switch method {
    case "available":
      return true
    case "start":
      job?.cancel()
      job = try Job(
        path: a["path"] as! String,
        width: a["width"] as! Int,
        height: a["height"] as! Int,
        fps: a["fps"] as! Int)
      return true
    case "frame":
      guard let job = job else { throw Err.noJob }
      let data = (a["rgba"] as! FlutterStandardTypedData).data
      try job.append(rgba: data, repeat: a["repeat"] as? Int ?? 1)
      return true
    case "finish":
      guard let j = job else { throw Err.noJob }
      job = nil
      finishing = j
      j.finish(
        audio: (a["audio"] as? String).map { URL(fileURLWithPath: $0) },
        start: a["audioStart"] as? Double ?? 0,
        end: a["audioEnd"] as? Double ?? 0,
        offset: a["audioOffset"] as? Double ?? 0,
        fadeIn: a["fadeIn"] as? Double ?? 0,
        fadeOut: a["fadeOut"] as? Double ?? 0
      ) { r in
        queue.async { finishing = nil }
        DispatchQueue.main.async {
          let f = pendingFinish
          pendingFinish = nil
          switch r {
          case .success(let p): f?(p)
          case .failure(let e): f?(FlutterError(code: "video", message: "\(e)", details: nil))
          }
        }
      }
      return nil
    case "cancel":
      job?.cancel()
      job = nil
      finishing?.cancel()
      finishing = nil
      return true
    default:
      throw Err.unknown(method)
    }
  }

  enum Err: Error {
    case noJob, unknown(String), writer(String), noTrack
  }

  final class Job {
    let out: URL
    let video: URL
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    let width: Int, height: Int, fps: Int32
    var frames: Int64 = 0
    var export: AVAssetExportSession?

    init(path: String, width: Int, height: Int, fps: Int) throws {
      out = URL(fileURLWithPath: path)
      video = out.deletingPathExtension().appendingPathExtension("video.mp4")
      for u in [out, video] { try? FileManager.default.removeItem(at: u) }
      self.width = width
      self.height = height
      self.fps = Int32(fps)
      writer = try AVAssetWriter(outputURL: video, fileType: .mp4)
      input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: width * height * 4,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
          AVVideoMaxKeyFrameIntervalKey: fps * 2,
        ],
      ])
      input.expectsMediaDataInRealTime = false
      adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ])
      writer.add(input)
      guard writer.startWriting() else { throw Err.writer("\(String(describing: writer.error))") }
      writer.startSession(atSourceTime: .zero)
    }

    func append(rgba: Data, repeat count: Int) throws {
      guard let pool = adaptor.pixelBufferPool else { throw Err.writer("no pool") }
      var pb: CVPixelBuffer?
      CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
      guard let buffer = pb else { throw Err.writer("no buffer") }
      CVPixelBufferLockBaseAddress(buffer, [])
      rgba.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
        var s = vImage_Buffer(
          data: UnsafeMutableRawPointer(mutating: src.baseAddress!),
          height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
        var d = vImage_Buffer(
          data: CVPixelBufferGetBaseAddress(buffer)!,
          height: vImagePixelCount(height), width: vImagePixelCount(width),
          rowBytes: CVPixelBufferGetBytesPerRow(buffer))
        let map: [UInt8] = [2, 1, 0, 3]  // RGBA -> BGRA
        vImagePermuteChannels_ARGB8888(&s, &d, map, vImage_Flags(kvImageNoFlags))
      }
      CVPixelBufferUnlockBaseAddress(buffer, [])
      for _ in 0..<max(1, count) {
        while !input.isReadyForMoreMediaData {
          if writer.status == .failed { throw Err.writer("\(String(describing: writer.error))") }
          usleep(2000)
        }
        let t = CMTime(value: frames, timescale: fps)
        if !adaptor.append(buffer, withPresentationTime: t) {
          throw Err.writer("\(String(describing: writer.error))")
        }
        frames += 1
      }
    }

    func cancel() {
      export?.cancelExport()
      if writer.status == .writing { writer.cancelWriting() }
      for u in [out, video] { try? FileManager.default.removeItem(at: u) }
    }

    func finish(
      audio: URL?, start: Double, end: Double, offset: Double,
      fadeIn: Double, fadeOut: Double,
      done: @escaping (Result<String, Error>) -> Void
    ) {
      input.markAsFinished()
      writer.endSession(atSourceTime: CMTime(value: frames, timescale: fps))
      writer.finishWriting { [self] in
        guard writer.status == .completed else {
          return done(.failure(Err.writer("\(String(describing: writer.error))")))
        }
        do {
          try compose(audio: audio, start: start, end: end, offset: offset,
                      fadeIn: fadeIn, fadeOut: fadeOut, done: done)
        } catch {
          done(.failure(error))
        }
      }
    }

    private func compose(
      audio: URL?, start: Double, end: Double, offset: Double,
      fadeIn: Double, fadeOut: Double,
      done: @escaping (Result<String, Error>) -> Void
    ) throws {
      let precise = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
      let comp = AVMutableComposition()
      let vAsset = AVURLAsset(url: video, options: precise)
      guard let vt = vAsset.tracks(withMediaType: .video).first,
        let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
      else { throw Err.noTrack }
      let length = CMTime(value: frames, timescale: fps)
      try cv.insertTimeRange(CMTimeRange(start: .zero, duration: min(length, vAsset.duration)), of: vt, at: .zero)
      var mix: AVMutableAudioMix?
      if let audio = audio, end > start {
        let aAsset = AVURLAsset(url: audio, options: precise)
        guard let at = aAsset.tracks(withMediaType: .audio).first,
          let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Err.noTrack }
        let scale: CMTimeScale = 48000
        let from = CMTime(seconds: start, preferredTimescale: scale)
        let dur = CMTime(seconds: end - start, preferredTimescale: scale)
        let at0 = CMTime(seconds: offset, preferredTimescale: scale)
        try ca.insertTimeRange(CMTimeRange(start: from, duration: dur), of: at, at: at0)
        let p = AVMutableAudioMixInputParameters(track: ca)
        p.setVolumeRamp(
          fromStartVolume: 0, toEndVolume: 1,
          timeRange: CMTimeRange(start: at0, duration: CMTime(seconds: fadeIn, preferredTimescale: scale)))
        p.setVolumeRamp(
          fromStartVolume: 1, toEndVolume: 0,
          timeRange: CMTimeRange(
            start: CMTime(seconds: offset + (end - start) - fadeOut, preferredTimescale: scale),
            duration: CMTime(seconds: fadeOut, preferredTimescale: scale)))
        mix = AVMutableAudioMix()
        mix!.inputParameters = [p]
      }
      guard let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
        throw Err.writer("no export session")
      }
      ex.outputURL = out
      ex.outputFileType = .mp4
      ex.audioMix = mix
      ex.shouldOptimizeForNetworkUse = true
      ex.timeRange = CMTimeRange(start: .zero, duration: length)
      export = ex
      ex.exportAsynchronously { [self] in
        try? FileManager.default.removeItem(at: video)
        if ex.status == .completed {
          done(.success(out.path))
        } else {
          done(.failure(Err.writer("\(String(describing: ex.error))")))
        }
      }
    }
  }
}
