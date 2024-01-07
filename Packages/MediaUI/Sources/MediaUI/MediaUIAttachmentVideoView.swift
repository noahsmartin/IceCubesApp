import AVKit
import DesignSystem
import Env
import Observation
import SwiftUI

@MainActor
@Observable public class MediaUIAttachmentVideoViewModel {
  var player: AVPlayer?
  private let url: URL
  let forceAutoPlay: Bool
  var isPlaying: Bool = false

  public init(url: URL, forceAutoPlay: Bool = false) {
    self.url = url
    self.forceAutoPlay = forceAutoPlay
  }

  func preparePlayer(autoPlay: Bool, isCompact: Bool) {
    player = .init(url: url)
    player?.audiovisualBackgroundPlaybackPolicy = .pauses
    if (autoPlay || forceAutoPlay) && !isCompact {
      player?.play()
      isPlaying = true
    } else {
      player?.pause()
      isPlaying = false
    }
    guard let player else { return }
    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                           object: player.currentItem, queue: .main)
    { _ in
      Task { @MainActor [weak self] in
        if autoPlay || self?.forceAutoPlay == true {
          self?.play()
        }
      }
    }
  }

  func pause() {
    isPlaying = false
    player?.pause()
  }

  func play() {
    isPlaying = true
    player?.seek(to: CMTime.zero)
    player?.play()
  }

  deinit {
    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
  }
}

@MainActor
public struct MediaUIAttachmentVideoView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.isCompact) private var isCompact
  @Environment(UserPreferences.self) private var preferences
  @Environment(Theme.self) private var theme

  @State var viewModel: MediaUIAttachmentVideoViewModel
  @State var isFullScreen: Bool = false

  public init(viewModel: MediaUIAttachmentVideoViewModel) {
    _viewModel = .init(wrappedValue: viewModel)
  }

  public var body: some View {
    videoView
    .onAppear {
      try? AVAudioSession.sharedInstance().setCategory(.playback)
      viewModel.preparePlayer(autoPlay: isFullScreen ? true : preferences.autoPlayVideo,
                              isCompact: isCompact)
    }
    .onDisappear {
      try? AVAudioSession.sharedInstance().setCategory(.ambient)
      viewModel.pause()
    }
    .onTapGesture {
      isFullScreen = true
    }
    .fullScreenCover(isPresented: $isFullScreen) {
      NavigationStack {
        videoView
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button { isFullScreen.toggle() } label: {
                Image(systemName: "xmark.circle")
              }
            }
          }
      }
    }
    .cornerRadius(4)
    .onChange(of: scenePhase) { _, newValue in
      switch newValue {
      case .background, .inactive:
        viewModel.pause()
      case .active:
        if (preferences.autoPlayVideo || viewModel.forceAutoPlay || isFullScreen) && !isCompact {
          viewModel.play()
        }
      default:
        break
      }
    }
  }
  
  private var videoView: some View {
    VideoPlayer(player: viewModel.player, videoOverlay: {
      if !preferences.autoPlayVideo, 
          !viewModel.forceAutoPlay,
         !isFullScreen,
          !viewModel.isPlaying {
        Button(action: {
          viewModel.play()
        }, label: {
          Image(systemName: "play.fill")
            .font(isCompact ? .body : .largeTitle)
            .foregroundColor(theme.tintColor)
            .padding(.all, isCompact ? 6 : nil)
            .background(Circle().fill(.thinMaterial))
            .padding(theme.statusDisplayStyle == .compact ? 0 : 10)
        })
      }
    })
    .accessibilityAddTraits(.startsMediaSession)
  }
}
