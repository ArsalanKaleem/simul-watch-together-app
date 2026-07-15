import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/firebase_service.dart';
import '../services/livekit_service.dart';
import '../services/theme_controller.dart';
import '../services/youtube_sync_service.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/live_share_viewer.dart';
import '../widgets/chat/floating_chat.dart';
import '../widgets/reactions/live_reactions.dart';
import '../widgets/queue/video_queue_panel.dart';
import '../widgets/game/connect4_screen.dart';
import '../models/activity_log.dart';
import '../screens/about_screen.dart';
import '../screens/settings_screen.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String userName;
  const RoomScreen({super.key, required this.roomId, required this.userName});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _urlCtrl     = TextEditingController();
  // The placeholder's URL field and the below-video URL field are in
  // DIFFERENT subtrees that swap in the same frame when a video loads. They
  // must not share one TextEditingController — a single controller attached
  // to a TextField being destroyed and another being created in the same
  // frame is what triggered the focus-scope assertion crash.
  final _placeholderUrlCtrl = TextEditingController();
  final _videoKey    = GlobalKey<VideoPlayerWidgetState>();
  late TabController _bottomTab;

  // Video state
  String? _currentVideoId;
  String  _myUserId          = '';

  // View mode: 'youtube' | 'screenshare'
  String _viewMode = 'youtube';

  StreamSubscription? _syncSub;
  bool _showReactions = false;

  @override
  void initState() {
    super.initState();
    _bottomTab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final fb   = context.read<FirebaseService>();
    final sync = context.read<YouTubeSyncService>();
    final lk   = context.read<LiveKitService>();

    // Phase 1: Firebase room state (chat, presence, sync). Without this the
    // room genuinely can't function, so failure gets a clear toast.
    try {
      await fb.initializeRoom(widget.roomId, widget.userName);
      _myUserId = fb.currentUser?.id ?? '';
    } catch (e) {
      debugPrint('Room init (Firebase) error: $e');
      if (mounted) {
        _snack("Couldn't reach the room server — check your internet "
            'connection and re-enter the room.', isError: true);
      }
      return;
    }

    // Phase 2: LiveKit (voice + screen share). This failing should NOT kill
    // the room — video sync and chat still work — so degrade gracefully and
    // tell the person what to do.
    if (_myUserId.isNotEmpty) {
      try {
        lk.addListener(_onLiveKitChanged);
        await lk.connect(
          roomId     : widget.roomId,
          userId     : _myUserId,
          displayName: widget.userName,
          role       : fb.isHost ? SimulRole.host : SimulRole.viewer,
        );
      } catch (e) {
        debugPrint('Room init (LiveKit) error: $e');
        if (mounted) {
          _snack('Voice & screen share are offline — open Settings and check '
              'your LiveKit setup. Watching together still works.',
              isError: true);
        }
      }
    }

    // Phase 3: video sync stream. Independent of LiveKit.
    try {
      sync.listenToVideoSync(widget.roomId, _myUserId);
      _syncSub = sync.videoStateStream.listen((state) {
        if (!mounted) return;
        final action  = state['action']    as String?;
        final pos     = (state['position'] as num?)?.toDouble() ?? 0.0;
        final playing = state['isPlaying'] as bool? ?? true;
        switch (action) {
          case 'load':
            final newId = state['videoId'] as String?;
            // Ignore echoes of the video we're already showing — rebuilding
            // the player subtree for no reason is both wasteful and a chance
            // to hit the swap bug again.
            if (newId == null ||
                (newId == _currentVideoId && _viewMode == 'youtube')) {
              break;
            }
            // Release focus before the placeholder subtree (which owns a text
            // field) is replaced by the player.
            FocusManager.instance.primaryFocus?.unfocus();
            _safeSetState(() {
              _currentVideoId = newId;
              _viewMode       = 'youtube';
            });
          case 'play':
            _videoKey.currentState?.syncTo(pos, true);
          case 'pause':
            _videoKey.currentState?.syncTo(pos, false);
          case 'seek':
            _videoKey.currentState?.seekTo(pos);
          case 'sync':
            final vs = _videoKey.currentState;
            if (vs != null && (vs.currentPosition - pos).abs() > 3.0) {
              vs.syncTo(pos, playing);
            }
        }
      });
    } catch (e) {
      debugPrint('Room init (sync) error: $e');
      if (mounted) {
        _snack('Video sync is unavailable right now — try re-entering the room.',
            isError: true);
      }
    }
  }

  /// Flips the view between YouTube and screen-share as sharing starts/stops,
  /// mirroring how the old ScreenShareService listener used to behave.
  void _onLiveKitChanged() {
    if (!mounted) return;
    final lk = context.read<LiveKitService>();
    final isSharingNow = lk.isSharing || lk.hasRemoteShare;
    // These also swap the main view subtree, and they fire from
    // notifyListeners() which can land mid-frame — same hazard as the sync
    // stream, so go through the phase-safe path.
    if (isSharingNow && _viewMode != 'screenshare') {
      _safeSetState(() => _viewMode = 'screenshare');
    } else if (!isSharingNow && _viewMode == 'screenshare') {
      _safeSetState(() => _viewMode = 'youtube');
    }
  }

  // ── Video loading ──────────────────────────────────────────────────────────

  void _loadVideo(String videoId, String title) {
    _safeSetState(() {
      _currentVideoId    = videoId;
      _viewMode          = 'youtube';
    });
    context.read<YouTubeSyncService>().sendVideoLoaded(
        widget.roomId, _myUserId, videoId, title: title);
  }

  void _loadFromUrl(TextEditingController source) {
    final url = source.text.trim();
    if (url.isEmpty) return;
    final id = _extractYouTubeId(url);
    if (id == null) {
      _snack('Could not recognise a YouTube URL', isError: true);
      return;
    }
    // The URL field lives in a subtree that is about to be torn down (the
    // placeholder is replaced by the player in the same frame). If it still
    // holds focus when its ancestor focus scope is disposed, Flutter throws
    // "_dependents.isEmpty"/"not a descendant" assertions. Drop focus first.
    FocusManager.instance.primaryFocus?.unfocus();
    source.clear();
    _loadVideo(id, 'YouTube Video');
  }

  /// Extracts a YouTube video ID from any common URL format.
  String? _extractYouTubeId(String input) {
    final patterns = [
      // watch / share / shorts / embed / live URLs on any youtube host
      // (www., m., music.) plus youtu.be short links.
      RegExp(r'(?:youtube\.com/watch\?(?:.*&)?v=|youtu\.be/|youtube\.com/shorts/|youtube\.com/embed/|youtube\.com/live/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'^([a-zA-Z0-9_-]{11})$'), // raw ID
    ];
    for (final p in patterns) {
      final m = p.firstMatch(input);
      if (m != null) return m.group(1);
    }
    return null;
  }

  // ── Screen share ───────────────────────────────────────────────────────────

  Future<void> _toggleScreenShare() async {
    if (!AppConfig.isScreenShareSupported) {
      // Phones can't capture a browser tab — but they CAN share what they're
      // watching by pasting its link, which loads it in sync for everyone.
      _showShareLinkSheet();
      return;
    }
    final lk = context.read<LiveKitService>();
    final wasSharing = lk.isSharing;
    await lk.toggleScreenShare();
    if (!wasSharing && !lk.isSharing) {
      // Attempted to start but it didn't take (permission denied / cancelled).
      _snack('Screen share cancelled or unavailable');
    }
  }

  /// Mobile alternative to tab sharing: paste a video link and it loads for
  /// the whole room via the existing sync pipeline.
  void _showShareLinkSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SimulColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: SimulColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.link_rounded, color: SimulColors.info, size: 28),
          const SizedBox(height: 8),
          const Text('Share by link',
              style: TextStyle(
                  color: SimulColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Tab sharing needs a desktop browser — on your phone, paste a '
                'YouTube link instead and it plays for everyone, in sync.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: SimulColors.faint, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: SimulColors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=…',
                  hintStyle: const TextStyle(
                      color: SimulColors.subtle, fontSize: 13),
                  filled: true,
                  fillColor: SimulColors.card,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Paste from clipboard',
              icon: const Icon(Icons.content_paste_rounded,
                  color: SimulColors.faint, size: 20),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) ctrl.text = data!.text!.trim();
              },
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final url = ctrl.text.trim();
                // Drop focus BEFORE popping — the sheet's text field is being
                // destroyed at the same moment _loadVideo swaps the video
                // subtree, which is exactly the focus-scope teardown that
                // crashed the app.
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(ctx);
                if (url.isEmpty) return;
                final id = _extractYouTubeId(url);
                if (id == null) {
                  _snack('Could not recognise a YouTube URL', isError: true);
                  return;
                }
                _loadVideo(id, 'YouTube Video');
              },
              child: const Text('Play for everyone'),
            ),
          ),
        ]),
      ),
    ).whenComplete(ctrl.dispose);
  }

  // ── Voice chat ─────────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    await context.read<LiveKitService>().toggleMic();
  }

  // Builds the AppBar's action icons, adapting to available width so they
  // never overflow. On narrow phones, the screen-share toggle is dropped from
  // here (it's still reachable from the drawer) and the participant chip
  // shrinks to an icon-only tap target — this alone was enough width to
  // reliably overflow a 360–390px-wide phone AppBar before.
  List<Widget> _buildAppBarActions(
      BuildContext context, LiveKitService lk, int participantCount) {
    final width = MediaQuery.of(context).size.width;
    final narrow = width < 600;

    return [
      // Shown when the browser is blocking audio autoplay — one tap wires
      // up hearing everyone (mic + shared tab audio). Rare/contextual, so it
      // always gets a spot even on narrow screens.
      if (lk.isAudioBlocked)
        IconButton(
          icon: const Icon(Icons.volume_up_rounded,
              color: SimulColors.info, size: 20),
          tooltip: 'Enable sound',
          onPressed: () => lk.enableAudioPlayback(),
        ),

      // Screen share toggle — only in the AppBar on wide screens. On narrow
      // screens it lives in the drawer instead, to keep the bar from
      // overflowing.
      if (AppConfig.isScreenShareSupported && !narrow)
        IconButton(
          icon: Icon(
            lk.isSharing
                ? Icons.stop_screen_share_rounded
                : Icons.screen_share_rounded,
            color: lk.isSharing ? SimulColors.shareActive : SimulColors.faint,
            size: 20,
          ),
          tooltip: lk.isSharing ? 'Stop sharing' : 'Share screen / tab',
          onPressed: _toggleScreenShare,
        ),

      // Voice chat — always present, it's the core control.
      IconButton(
        icon: Icon(
          lk.isMicOn && !lk.isMicMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
          color: lk.isMicOn && !lk.isMicMuted ? SimulColors.success : SimulColors.faint,
          size: 20,
        ),
        onPressed: _toggleVoice,
      ),

      // Participant count — icon-only on narrow screens to save width; full
      // chip with the count on wider screens.
      GestureDetector(
        onTap: _showParticipants,
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: EdgeInsets.symmetric(
              horizontal: narrow ? 6 : 10, vertical: 5),
          decoration: BoxDecoration(
            color: SimulColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SimulColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.people_outline, color: SimulColors.faint, size: 14),
            if (!narrow) ...[
              const SizedBox(width: 4),
              Text('$participantCount',
                  style: const TextStyle(color: SimulColors.faint, fontSize: 12)),
            ],
          ]),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.menu_rounded, color: SimulColors.faint),
        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
    ];
  }

  // ── Invite / participants / activity ────────────────────────────────────────

  void _showInvite() {
    final wide = MediaQuery.of(context).size.width >= 700;
    if (wide) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: SimulColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SimulColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: _InviteContent(roomId: widget.roomId, onDone: () {
                  Navigator.pop(context);
                }),
              ),
            ),
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: SimulColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: _InviteContent(roomId: widget.roomId, onDone: () {
          Navigator.pop(context);
        }),
      ),
    );
  }

  void _showParticipants() {
    final fb = context.read<FirebaseService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: SimulColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ChangeNotifierProvider.value(
        value: fb,
        child: _ParticipantSheet(roomId: widget.roomId),
      ),
    );
  }

  void _showActivity() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SimulColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ActivitySheet(
        roomId: widget.roomId,
        stream: context.read<FirebaseService>().getActivityStream(widget.roomId),
      ),
    );
  }

  String? _lastSnackMsg;
  DateTime? _lastSnackAt;

  /// setState that is safe to call from a stream callback.
  ///
  /// Firestore sync events can arrive while Flutter is in the middle of a
  /// build/layout pass. Mutating the element tree at that moment is what
  /// produced the "_dependents.isEmpty" / "not a descendant" framework
  /// assertions on the receiving client. If we're mid-frame, defer to just
  /// after it instead.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    final now = DateTime.now();
    // Swallow duplicate messages fired in quick succession (e.g. a
    // connection retry loop) instead of letting them stack up.
    if (_lastSnackMsg == msg &&
        _lastSnackAt != null &&
        now.difference(_lastSnackAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastSnackMsg = msg;
    _lastSnackAt  = now;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? SimulColors.error : SimulColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fb               = context.watch<FirebaseService>();
    final lk                = context.watch<LiveKitService>();
    final participantCount = fb.participantIds.length;
    final isSharing        = lk.isSharing || lk.hasRemoteShare;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SimulColors.black,
      endDrawer: _AppDrawer(
        onInvite          : _showInvite,
        onActivity        : _showActivity,
        onToggleReactions : () => setState(() => _showReactions = !_showReactions),
        showReactions     : _showReactions,
        isSharing         : lk.isSharing,
        onToggleScreenShare: _toggleScreenShare,
      ),
      appBar: AppBar(
        backgroundColor: SimulColors.black,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: SimulColors.white),
          onPressed: () async {
            // Capture everything context-derived BEFORE the await, so nothing
            // below touches `context` across the async gap (fixes the
            // use_build_context_synchronously lint).
            final navigator = Navigator.of(context);
            final lkService = context.read<LiveKitService>();
            final fbService = context.read<FirebaseService>();
            final leave = await _confirmLeave();
            if (leave && mounted) {
              if (lk.isSharing) await lk.stopScreenShare();
              await lkService.disconnect();
              await fbService.leaveRoom();
              if (mounted) navigator.pop();
            }
          },
        ),
        // titleSpacing: 0 so the title gets the max width available before
        // squeezing into the action icons on narrow phones.
        titleSpacing: 0,
        title: Builder(builder: (context) {
          // Below this width, the participant "Live/Waiting" pill is dropped
          // from the title row — it's decorative, and the room code chip
          // (which people actually need to read/tap) gets priority.
          final narrow = MediaQuery.of(context).size.width < 380;
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Flexible(
                  child: Text('SIMUL',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          color: SimulColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
                if (!narrow) ...[
                  const SizedBox(width: 8),
                  _StatusPill(active: participantCount >= 2),
                ],
              ]),
              _RoomCodeChip(roomId: widget.roomId),
            ],
          );
        }),
        actions: _buildAppBarActions(context, lk, participantCount),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          return wide
              ? _wideBody(participantCount, isSharing)
              : _mobileBody(participantCount, isSharing);
        },
      ),
      floatingActionButton: FloatingChat(
          roomId: widget.roomId, userName: widget.userName),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ── Responsive layout pieces ────────────────────────────────────────────────

  Widget _videoStack(int participantCount, bool isSharing) {
    return Stack(children: [
      _buildMainView(participantCount),
      if (_showReactions && (_currentVideoId != null || isSharing))
        Positioned.fill(child: LiveReactions(roomId: widget.roomId)),
    ]);
  }

  Widget _belowVideoBars(bool isSharing) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_viewMode == 'youtube' && _currentVideoId != null)
        _UrlBar(ctrl: _urlCtrl, onLoad: () => _loadFromUrl(_urlCtrl)),
      if (_viewMode == 'screenshare')
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: SimulColors.surface,
          child: Row(children: [
            const Icon(Icons.screen_share_rounded,
                color: SimulColors.shareActive, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.watch<LiveKitService>().isSharing
                    ? 'Sharing your screen with everyone in the room'
                    : 'Someone is sharing their screen',
                style: const TextStyle(color: SimulColors.faint, fontSize: 12),
              ),
            ),
            if (context.watch<LiveKitService>().isSharing)
              GestureDetector(
                onTap: _toggleScreenShare,
                child: const Text('Stop',
                    style: TextStyle(
                        color: SimulColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
    ]);
  }

  Widget _tabBar({bool desktop = false}) {
    if (!desktop) {
      return Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: SimulColors.border))),
        child: TabBar(
          controller: _bottomTab,
          indicatorColor: SimulColors.white,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: SimulColors.white,
          unselectedLabelColor: SimulColors.faint,
          labelStyle:
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.queue_music_rounded, size: 18), text: 'Queue'),
            Tab(icon: Icon(Icons.games_rounded, size: 18), text: 'Games'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Activity'),
          ],
        ),
      );
    }

    // Desktop: a pill-style segmented control instead of a cramped TabBar.
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SimulColors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SimulColors.border),
      ),
      child: AnimatedBuilder(
        animation: _bottomTab,
        builder: (_, __) {
          const items = [
            (Icons.queue_music_rounded, 'Queue'),
            (Icons.games_rounded, 'Games'),
            (Icons.bar_chart_rounded, 'Activity'),
          ];
          return Row(
            children: List.generate(items.length, (i) {
              final selected = _bottomTab.index == i;
              return Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _bottomTab.index = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? SimulColors.card : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: selected
                            ? Border.all(color: SimulColors.border)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(items[i].$1,
                              size: 15,
                              color: selected
                                  ? SimulColors.white
                                  : SimulColors.faint),
                          const SizedBox(width: 6),
                          Text(items[i].$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? SimulColors.white
                                    : SimulColors.faint,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _tabViews() => TabBarView(
    controller: _bottomTab,
    children: [
      VideoQueuePanel(
          roomId: widget.roomId,
          onVideoSelected: (id, title) => _loadVideo(id, title)),
      Connect4Screen(roomId: widget.roomId),
      _ActivityTab(roomId: widget.roomId),
    ],
  );

  /// Phone / portrait layout — video on top, tabs below.
  Widget _mobileBody(int participantCount, bool isSharing) {
    return Column(children: [
      _videoStack(participantCount, isSharing),
      _belowVideoBars(isSharing),
      _tabBar(),
      Expanded(child: _tabViews()),
    ]);
  }

  /// Desktop / wide layout — centred video on the left, docked panel on the right.
  Widget _wideBody(int participantCount, bool isSharing) {
    final fb = context.watch<FirebaseService>();
    return Row(children: [
      Expanded(
        child: Container(
          color: SimulColors.black,
          padding: const EdgeInsets.fromLTRB(32, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: SimulColors.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _videoStack(participantCount, isSharing),
                                _belowVideoBars(isSharing),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DesktopParticipantsStrip(
                          roomId: widget.roomId,
                          onInvite: _showInvite,
                          onTapParticipants: _showParticipants,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Container(
        width: 420,
        decoration: const BoxDecoration(
          color: SimulColors.surface,
          border: Border(left: BorderSide(color: SimulColors.border)),
        ),
        child: Column(children: [
          _SidebarHeader(
            roomId: widget.roomId,
            isHost: fb.isHost,
            onInvite: _showInvite,
          ),
          _tabBar(desktop: true),
          Expanded(child: _tabViews()),
        ]),
      ),
    ]);
  }

  Widget _buildMainView(int participantCount) {
    final lk = context.watch<LiveKitService>();

    // Local screen share takes priority — this is our own preview.
    if (_viewMode == 'screenshare' && lk.isSharing) {
      return LiveShareViewer(isLocal: true, onStop: _toggleScreenShare);
    }

    // Someone else in the room is sharing their screen/tab — show it live.
    if (lk.hasRemoteShare) {
      return const LiveShareViewer(isLocal: false);
    }

    // YouTube player
    if (_currentVideoId != null) {
      return VideoPlayerWidget(
        key      : _videoKey,
        videoId  : _currentVideoId!,
        onPlayPause: (playing, pos) {
          final sync = context.read<YouTubeSyncService>();
          if (playing) {
            sync.sendPlayEvent(widget.roomId, _myUserId, pos);
          } else {
            sync.sendPauseEvent(widget.roomId, _myUserId, pos);
          }
        },
        onSeek: (pos) => context.read<YouTubeSyncService>()
            .sendSeekEvent(widget.roomId, _myUserId, pos),
        onPositionUpdate: (pos, playing) => context.read<YouTubeSyncService>()
            .sendPositionSync(widget.roomId, _myUserId, pos, playing),
        onVideoEnded: _onVideoEnded,
        onPlayerError: (reason) =>
            _snack('Video failed to play: $reason', isError: true),
      );
    }

    // Placeholder
    return _VideoPlaceholder(
      urlCtrl         : _placeholderUrlCtrl,
      onLoad          : () => _loadFromUrl(_placeholderUrlCtrl),
      participantCount: participantCount,
      onShareTap      : _toggleScreenShare,
    );
  }

  void _onVideoEnded() async {
    final svc        = context.read<FirebaseService>();
    final queueItems = await svc.getQueueStream(widget.roomId).first;
    if (queueItems.isNotEmpty && mounted) {
      final next = queueItems.first;
      await svc.removeFromQueue(widget.roomId, next.id);
      _loadVideo(next.videoId, next.title);
    }
  }

  Future<bool> _confirmLeave() async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: SimulColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Room?',
            style: TextStyle(color: SimulColors.white)),
        content: const Text('Are you sure you want to leave?',
            style: TextStyle(color: SimulColors.faint)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay', style: TextStyle(color: SimulColors.faint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _urlCtrl.dispose();
    _placeholderUrlCtrl.dispose();
    _bottomTab.dispose();
    final lk = context.read<LiveKitService>();
    lk.removeListener(_onLiveKitChanged);
    lk.disconnect();
    context.read<YouTubeSyncService>().stopListening();
    super.dispose();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: (active ? SimulColors.success : SimulColors.muted).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
          color: (active ? SimulColors.success : SimulColors.muted).withValues(alpha: 0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 5, height: 5,
        decoration: BoxDecoration(
            color: active ? SimulColors.success : SimulColors.muted,
            shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(active ? 'Live' : 'Waiting',
          style: TextStyle(
              color: active ? SimulColors.success : SimulColors.muted,
              fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _VideoPlaceholder extends StatelessWidget {
  final TextEditingController urlCtrl;
  final VoidCallback onLoad;
  final int participantCount;
  final VoidCallback? onShareTap;
  const _VideoPlaceholder({
    required this.urlCtrl,
    required this.onLoad,
    required this.participantCount,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Container(
      color: SimulColors.surface,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.play_circle_outline_rounded,
            color: SimulColors.muted, size: 48),
        const SizedBox(height: 12),
        Text(
          participantCount < 2
              ? 'Waiting for someone to join…'
              : 'Paste a YouTube link to begin',
          style: const TextStyle(color: SimulColors.faint, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (participantCount >= 2) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _UrlBar(ctrl: urlCtrl, onLoad: onLoad),
          ),
          if (onShareTap != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onShareTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: SimulColors.shareActive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: SimulColors.shareActive.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.screen_share_rounded,
                      color: SimulColors.shareActive, size: 16),
                  const SizedBox(width: 8),
                  Text(
                      AppConfig.isScreenShareSupported
                          ? 'Share your screen / tab'
                          : 'Share a video by link',
                      style: const TextStyle(
                          color: SimulColors.shareActive,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ],
        ],
      ]),
    ),
  );
}

class _UrlBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onLoad;
  const _UrlBar({required this.ctrl, required this.onLoad});

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      ctrl.text = data.text!.trim();
      onLoad();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: SimulColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SimulColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.play_circle_outline_rounded,
            color: SimulColors.error, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: SimulColors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Paste a YouTube link to watch together…',
              hintStyle: TextStyle(color: SimulColors.subtle, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (_) => onLoad(),
          ),
        ),
        IconButton(
          tooltip: 'Paste & play',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.content_paste_go_rounded,
              color: SimulColors.faint, size: 18),
          onPressed: _pasteFromClipboard,
        ),
        const SizedBox(width: 2),
        Material(
          color: SimulColors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onLoad,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.play_arrow_rounded,
                    color: SimulColors.black, size: 16),
                SizedBox(width: 4),
                Text('Play',
                    style: TextStyle(
                        color: SimulColors.black,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ]),
    ),
  );
}

// ── Participant sheet ──────────────────────────────────────────────────────────

class _ParticipantSheet extends StatelessWidget {
  final String roomId;
  const _ParticipantSheet({required this.roomId});

  @override
  Widget build(BuildContext context) {
    final fb     = context.watch<FirebaseService>();
    final lk     = context.watch<LiveKitService>();
    final ids    = fb.participantIds;
    final names  = fb.participantNames;
    final isHost = fb.isHost;
    final myId   = fb.currentUser?.id ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('Participants',
              style: TextStyle(
                  color: SimulColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: SimulColors.muted,
                borderRadius: BorderRadius.circular(8)),
            child: Text('${ids.length}',
                style: const TextStyle(color: SimulColors.white, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 16),
        ...List.generate(ids.length, (i) {
          final id   = ids[i];
          final name = i < names.length && names[i].trim().isNotEmpty
              ? names[i]
              : 'User';
          final initial = name.trim().isNotEmpty
              ? name.trim()[0].toUpperCase()
              : '?';
          final isMod      = fb.isModerator(id);
          final isRoomHost = id == fb.hostId;
          final isSpeaking = lk.speakingParticipants.contains(id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: SimulColors.muted,
                    shape: BoxShape.circle,
                    border: isSpeaking
                        ? Border.all(color: SimulColors.success, width: 2)
                        : null),
                child: Center(
                    child: Text(initial,
                        style: const TextStyle(
                            color: SimulColors.white,
                            fontWeight: FontWeight.w600))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name,
                  style: const TextStyle(color: SimulColors.white, fontSize: 14))),
              if (isMod) const _Badge('MOD', SimulColors.info),
              if (isRoomHost) const _Badge('HOST', SimulColors.white),
              if (isHost && id != myId) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => isMod
                      ? fb.demoteModerator(roomId, id, name)
                      : fb.promoteModerator(roomId, id, name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SimulColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: SimulColors.border),
                    ),
                    child: Text(isMod ? 'Demote' : 'Mod',
                        style: const TextStyle(
                            color: SimulColors.faint, fontSize: 11)),
                  ),
                ),
              ],
            ]),
          );
        }),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700)),
  );
}

// ── Shared chrome (used on both mobile and desktop) ─────────────────────────────

/// A room code that's also a tap-to-copy control, with a small confirmation
/// state so people get feedback without needing to watch for a snackbar.
class _RoomCodeChip extends StatefulWidget {
  final String roomId;
  final bool large;
  const _RoomCodeChip({required this.roomId, this.large = false});

  @override
  State<_RoomCodeChip> createState() => _RoomCodeChipState();
}

class _RoomCodeChipState extends State<_RoomCodeChip> {
  bool _copied = false;
  Timer? _resetTimer;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.roomId));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final large = widget.large;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: _copied ? 'Copied!' : 'Tap to copy room code',
        child: GestureDetector(
          onTap: _copy,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
                horizontal: large ? 18 : 6, vertical: large ? 10 : 1),
            decoration: BoxDecoration(
              color: _copied
                  ? SimulColors.success.withValues(alpha: 0.12)
                  : (large ? SimulColors.surface : Colors.transparent),
              borderRadius: BorderRadius.circular(large ? 12 : 5),
              border: large
                  ? Border.all(
                  color: _copied ? SimulColors.success : SimulColors.border)
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.roomId,
                  style: TextStyle(
                    color: _copied
                        ? SimulColors.success
                        : (large ? SimulColors.white : SimulColors.faint),
                    fontSize: large ? 26 : 11,
                    fontWeight: large ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: large ? 4 : 0.5,
                    height: 1,
                  )),
              SizedBox(width: large ? 10 : 4),
              Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: large ? 18 : 10,
                color: _copied ? SimulColors.success : SimulColors.faint,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Shared body for the invite sheet/dialog — same content, different chrome
/// depending on whether it's presented as a bottom sheet or a dialog.
class _InviteContent extends StatelessWidget {
  final String roomId;
  final VoidCallback onDone;
  const _InviteContent({required this.roomId, required this.onDone});

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: SimulColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Expanded(
          child: Text('Invite to Room',
              style: TextStyle(
                  color: SimulColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onDone,
            child: const Icon(Icons.close_rounded,
                size: 20, color: SimulColors.faint),
          ),
        ),
      ]),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: SimulColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SimulColors.border),
        ),
        child: Column(children: [
          const Text('ROOM CODE',
              style: TextStyle(
                  color: SimulColors.faint,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          _RoomCodeChip(roomId: roomId, large: true),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: roomId));
                _snack(context, 'Room code copied!');
                onDone();
              },
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: SimulColors.faint),
              label: const Text('Copy Code',
                  style: TextStyle(color: SimulColors.faint)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: SimulColors.border),
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            )),
        const SizedBox(width: 12),
        Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final link = 'Join my SIMUL room!\nCode: $roomId';
                Clipboard.setData(ClipboardData(text: link));
                _snack(context, 'Invite text copied!');
                onDone();
              },
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
      ]),
    ]);
  }
}

// ── Desktop-only chrome ─────────────────────────────────────────────────────────

/// Sits atop the sidebar on wide screens: room identity + quick invite.
class _SidebarHeader extends StatelessWidget {
  final String roomId;
  final bool isHost;
  final VoidCallback onInvite;
  const _SidebarHeader({
    required this.roomId,
    required this.isHost,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: SimulColors.border))),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('ROOM CODE',
                    style: TextStyle(
                        color: SimulColors.subtle,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
                if (isHost) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SimulColors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('HOST',
                        style: TextStyle(
                            color: SimulColors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6)),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              Transform.translate(
                offset: const Offset(-18, 0),
                child: _RoomCodeChip(roomId: roomId, large: true),
              ),
            ],
          ),
        ),
        _IconGhostButton(
          icon: Icons.person_add_alt_1_rounded,
          tooltip: 'Invite',
          onTap: onInvite,
        ),
      ]),
    );
  }
}

class _IconGhostButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconGhostButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: SimulColors.card,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: SimulColors.border),
            ),
            child: Icon(icon, size: 17, color: SimulColors.white),
          ),
        ),
      ),
    );
  }
}

/// A thin strip under the video showing who's in the room — avatars +
/// names at a glance, without needing to open the participants sheet.
class _DesktopParticipantsStrip extends StatelessWidget {
  final String roomId;
  final VoidCallback onInvite;
  final VoidCallback onTapParticipants;
  const _DesktopParticipantsStrip({
    required this.roomId,
    required this.onInvite,
    required this.onTapParticipants,
  });

  @override
  Widget build(BuildContext context) {
    final fb    = context.watch<FirebaseService>();
    final names = fb.participantNames;
    final myId  = fb.currentUser?.id ?? '';
    final ids   = fb.participantIds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SimulColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SimulColors.border),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onTapParticipants,
          child: SizedBox(
            width: names.isEmpty
                ? 0
                : (names.length.clamp(0, 5) - 1) * 20.0 + 28,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(
                names.length.clamp(0, 5),
                    (i) => Positioned(
                  left: i * 20.0,
                  child: _Avatar(
                    label: names[i],
                    isMe: ids.length > i && ids[i] == myId,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: names.isEmpty ? 0 : 8),
        Expanded(
          child: Text(
            names.isEmpty
                ? 'Waiting for someone to join…'
                : names.join(', '),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SimulColors.faint, fontSize: 12.5),
          ),
        ),
        TextButton.icon(
          onPressed: onInvite,
          icon: const Icon(Icons.link_rounded, size: 14),
          label: const Text('Invite'),
          style: TextButton.styleFrom(
            foregroundColor: SimulColors.faint,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  final bool isMe;
  const _Avatar({required this.label, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMe ? SimulColors.white : SimulColors.card,
        border: Border.all(color: SimulColors.surface, width: 2),
      ),
      child: Center(
        child: Text(initial,
            style: TextStyle(
              color: isMe ? SimulColors.black : SimulColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}

// ── Activity sheets ────────────────────────────────────────────────────────────

class _ActivitySheet extends StatelessWidget {
  final String roomId;
  final Stream<List<ActivityLog>> stream;
  const _ActivitySheet({required this.roomId, required this.stream});

  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Activity',
            style: TextStyle(
                color: SimulColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ),
    ),
    Expanded(
      child: StreamBuilder<List<ActivityLog>>(
        stream: stream,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: SimulColors.white));
          }
          final logs = snap.data!;
          if (logs.isEmpty) {
            return const Center(
                child: Text('No activity yet',
                    style: TextStyle(color: SimulColors.subtle)));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: logs.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 10, top: 4),
                  decoration: const BoxDecoration(
                      color: SimulColors.muted, shape: BoxShape.circle),
                ),
                Expanded(child: Text(logs[i].message,
                    style: const TextStyle(
                        color: SimulColors.faint, fontSize: 13))),
              ]),
            ),
          );
        },
      ),
    ),
  ]);
}

class _ActivityTab extends StatelessWidget {
  final String roomId;
  const _ActivityTab({required this.roomId});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();
    return StreamBuilder<List<ActivityLog>>(
      stream: svc.getActivityStream(roomId),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: SimulColors.white));
        }
        final logs = snap.data!;
        if (logs.isEmpty) {
          return const Center(
              child: Text('No activity yet',
                  style: TextStyle(color: SimulColors.subtle, fontSize: 13)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.circle, size: 6, color: SimulColors.muted),
              const SizedBox(width: 10),
              Expanded(child: Text(logs[i].message,
                  style: const TextStyle(
                      color: SimulColors.faint, fontSize: 13))),
            ]),
          ),
        );
      },
    );
  }
}

// ── End-drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final VoidCallback onInvite;
  final VoidCallback onActivity;
  final VoidCallback onToggleReactions;
  final bool showReactions;
  final bool isSharing;
  final VoidCallback onToggleScreenShare;

  const _AppDrawer({
    required this.onInvite,
    required this.onActivity,
    required this.onToggleReactions,
    required this.showReactions,
    required this.isSharing,
    required this.onToggleScreenShare,
  });

  @override
  Widget build(BuildContext context) {
    // A fixed 280px drawer can exceed the viewport on very narrow phones
    // (some are ~320px wide), leaving no visible "scrim" and looking like a
    // full takeover. Cap it relative to screen width instead.
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 320 ? screenWidth * 0.9 : 280.0;

    return Drawer(
      backgroundColor: SimulColors.surface,
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: SimulColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SimulColors.border),
                  ),
                  child: const Center(
                    child: Text('S',
                        style: TextStyle(
                            color: SimulColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text('SIMUL',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: SimulColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      )),
                ),
              ]),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: SimulColors.border, height: 1),
            ),
            const SizedBox(height: 8),

            _DrawerTile(
              icon : Icons.link_rounded,
              label: 'Invite to Room',
              onTap: () { Navigator.pop(context); onInvite(); },
            ),
            _DrawerTile(
              icon : Icons.bar_chart_rounded,
              label: 'Activity Log',
              onTap: () { Navigator.pop(context); onActivity(); },
            ),
            _DrawerTile(
              icon : showReactions
                  ? Icons.emoji_emotions_outlined
                  : Icons.emoji_emotions_rounded,
              label: showReactions ? 'Hide Reactions' : 'Show Reactions',
              onTap: () { Navigator.pop(context); onToggleReactions(); },
            ),
            // Screen share also lives here so it's always reachable even on
            // narrow phones, where it's dropped from the AppBar to avoid
            // overflow. On mobile (no tab capture) this opens the
            // share-by-link sheet instead.
            _DrawerTile(
              icon : isSharing
                  ? Icons.stop_screen_share_rounded
                  : Icons.screen_share_rounded,
              label: isSharing
                  ? 'Stop Sharing'
                  : (AppConfig.isScreenShareSupported
                  ? 'Share Screen / Tab'
                  : 'Share a Video Link'),
              onTap: () { Navigator.pop(context); onToggleScreenShare(); },
            ),

            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: SimulColors.border, height: 1),
            ),
            const SizedBox(height: 8),

            _DrawerTile(
              icon : Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),

            _DrawerTile(
              icon : Icons.person_outline_rounded,
              label: 'About',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()));
              },
            ),

            Builder(builder: (context) {
              final isDark =
                  Theme.of(context).brightness == Brightness.dark;
              return _DrawerTile(
                icon: isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                label: isDark ? 'Light Mode' : 'Dark Mode',
                onTap: () => context
                    .read<ThemeController>()
                    .toggle(MediaQuery.platformBrightnessOf(context)),
              );
            }),

            const Spacer(),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text('SIMUL v1.1.0',
                  style: TextStyle(color: SimulColors.subtle, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, color: SimulColors.faint, size: 18),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                color: SimulColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              )),
        ]),
      ),
    );
  }
}