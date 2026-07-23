import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import '../data/communication_realtime_service.dart';

class CommunicationCallScreen extends StatefulWidget {
  const CommunicationCallScreen({
    super.key,
    required this.call,
    required this.person,
    required this.repository,
    required this.isCaller,
  });

  final Map<String, dynamic> call;
  final Map<String, dynamic> person;
  final AttendanceRepository repository;
  final bool isCaller;

  @override
  State<CommunicationCallScreen> createState() =>
      _CommunicationCallScreenState();
}

class _CommunicationCallScreenState extends State<CommunicationCallScreen> {
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? peer;
  MediaStream? localStream;
  StreamSubscription<Map<String, dynamic>>? callSubscription;
  final pendingCandidates = <RTCIceCandidate>[];
  bool remoteDescriptionReady = false;
  bool microphoneEnabled = true;
  bool cameraEnabled = true;
  bool speakerEnabled = true;
  bool ended = false;
  String status = 'Preparing secure call...';

  String get callId => widget.call['_id'].toString();
  bool get video => widget.call['type'] == 'video';
  String get personName =>
      widget.person['fullName']?.toString().isNotEmpty == true
          ? widget.person['fullName'].toString()
          : widget.person['username']?.toString() ??
              widget.call['callerName']?.toString() ??
              'IHWE User';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    callSubscription =
        CommunicationRealtimeService.instance.calls.listen(_handleCallEvent);
    try {
      final config = await widget.repository.communicationIceConfig();
      peer = await createPeerConnection({
        'iceServers':
            List<Map<String, dynamic>>.from(config['iceServers'] ?? const []),
        'sdpSemantics': 'unified-plan',
      });
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 720},
                'height': {'ideal': 1280},
                'frameRate': {'ideal': 24}
              }
            : false,
      });
      localRenderer.srcObject = localStream;
      for (final track in localStream!.getTracks()) {
        await peer!.addTrack(track, localStream!);
      }
      peer!.onTrack = (event) {
        if (event.streams.isNotEmpty && mounted) {
          setState(() => remoteRenderer.srcObject = event.streams.first);
        }
      };
      peer!.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        CommunicationRealtimeService.instance.emit('call:signal', {
          'callId': callId,
          'signal': {
            'type': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      };
      peer!.onConnectionState = (state) {
        if (!mounted) return;
        setState(() {
          status =
              state == RTCPeerConnectionState.RTCPeerConnectionStateConnected
                  ? 'Connected securely'
                  : state
                      .toString()
                      .replaceAll('RTCPeerConnectionState.', '')
                      .replaceAll('RTCPeerConnectionState', '');
        });
      };
      if (widget.isCaller) {
        if (mounted) setState(() => status = 'Ringing...');
      } else {
        await widget.repository.updateCommunicationCall(callId, 'accept');
        if (mounted) setState(() => status = 'Connecting...');
      }
    } catch (error) {
      if (mounted) setState(() => status = 'Call setup failed: $error');
      await _end(reason: 'setup-failed');
    }
  }

  Future<void> _handleCallEvent(Map<String, dynamic> event) async {
    if ((event['callId'] ?? event['_id'])?.toString() != callId || ended) {
      return;
    }
    if (event['event'] == 'accepted' && widget.isCaller) {
      await _createOffer();
      return;
    }
    if (event['event'] == 'ended') {
      ended = true;
      final callStatus = event['status']?.toString();
      final endReason = event['endReason']?.toString();
      if (mounted) {
        setState(() {
          status = callStatus == 'missed' || endReason == 'no-answer'
              ? 'No answer'
              : callStatus == 'rejected'
                  ? 'Call declined'
                  : 'Call ended';
        });
      }
      await _disposeMedia();
      if (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context);
      }
      return;
    }
    if (event['event'] != 'signal') return;
    final signal = Map<String, dynamic>.from(event['signal'] ?? {});
    final type = signal['type'];
    if (type == 'offer') {
      await peer?.setRemoteDescription(
          RTCSessionDescription(signal['sdp']?.toString(), 'offer'));
      remoteDescriptionReady = true;
      await _flushCandidates();
      final answer = await peer!.createAnswer();
      await peer!.setLocalDescription(answer);
      CommunicationRealtimeService.instance.emit('call:signal', {
        'callId': callId,
        'signal': {'type': 'answer', 'sdp': answer.sdp}
      });
    } else if (type == 'answer') {
      await peer?.setRemoteDescription(
          RTCSessionDescription(signal['sdp']?.toString(), 'answer'));
      remoteDescriptionReady = true;
      await _flushCandidates();
    } else if (type == 'candidate') {
      final candidate = RTCIceCandidate(
          signal['candidate']?.toString(),
          signal['sdpMid']?.toString(),
          int.tryParse('${signal['sdpMLineIndex']}'));
      if (remoteDescriptionReady) {
        await peer?.addCandidate(candidate);
      } else {
        pendingCandidates.add(candidate);
      }
    }
  }

  Future<void> _createOffer() async {
    final offer = await peer!.createOffer();
    await peer!.setLocalDescription(offer);
    CommunicationRealtimeService.instance.emit('call:signal', {
      'callId': callId,
      'signal': {'type': 'offer', 'sdp': offer.sdp}
    });
    if (mounted) setState(() => status = 'Connecting...');
  }

  Future<void> _flushCandidates() async {
    for (final candidate in pendingCandidates) {
      await peer?.addCandidate(candidate);
    }
    pendingCandidates.clear();
  }

  Future<void> _end({String reason = 'ended'}) async {
    if (ended) return;
    ended = true;
    try {
      await widget.repository
          .updateCommunicationCall(callId, 'end', reason: reason);
    } catch (_) {
      // The other participant may already have closed the call.
    }
    await _disposeMedia();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _disposeMedia() async {
    await callSubscription?.cancel();
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await localStream?.dispose();
    await peer?.close();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  @override
  void dispose() {
    if (!ended) {
      ended = true;
      widget.repository
          .updateCommunicationCall(callId, 'end', reason: 'screen-closed');
      _disposeMedia();
    }
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _end(reason: 'back-button');
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF071829),
          body: SafeArea(
            child: Stack(children: [
              if (video)
                Positioned.fill(
                    child: remoteRenderer.srcObject == null
                        ? _identity()
                        : RTCVideoView(remoteRenderer,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover))
              else
                Positioned.fill(child: _identity()),
              if (video && localRenderer.srcObject != null)
                Positioned(
                  right: 16,
                  top: 16,
                  width: 105,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: RTCVideoView(localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  ),
                ),
              Positioned(
                left: 18,
                top: 18,
                child: IconButton.filledTonal(
                    onPressed: () => _end(reason: 'back-button'),
                    icon: const Icon(Icons.arrow_back_rounded)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Column(children: [
                  Text(status,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _control(
                        microphoneEnabled
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded, () {
                      microphoneEnabled = !microphoneEnabled;
                      for (final track in localStream?.getAudioTracks() ?? []) {
                        track.enabled = microphoneEnabled;
                      }
                      setState(() {});
                    }),
                    const SizedBox(width: 13),
                    if (video) ...[
                      _control(
                          cameraEnabled
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded, () {
                        cameraEnabled = !cameraEnabled;
                        for (final track
                            in localStream?.getVideoTracks() ?? []) {
                          track.enabled = cameraEnabled;
                        }
                        setState(() {});
                      }),
                      const SizedBox(width: 13),
                      _control(Icons.cameraswitch_rounded, () async {
                        final tracks = localStream?.getVideoTracks() ?? [];
                        if (tracks.isNotEmpty) {
                          await Helper.switchCamera(tracks.first);
                        }
                      }),
                      const SizedBox(width: 13),
                    ],
                    _control(
                        speakerEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded, () {
                      speakerEnabled = !speakerEnabled;
                      Helper.setSpeakerphoneOn(speakerEnabled);
                      setState(() {});
                    }),
                    const SizedBox(width: 13),
                    _control(Icons.call_end_rounded,
                        () => _end(reason: 'user-ended'),
                        color: Colors.red),
                  ]),
                ]),
              )
            ]),
          ),
        ),
      );

  Widget _identity() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.green.withValues(alpha: .22),
              child: Text(
                  personName.isEmpty ? '?' : personName[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 42,
                      fontWeight: FontWeight.w900))),
          const SizedBox(height: 18),
          Text(personName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(video ? 'IHWE secure video call' : 'IHWE secure audio call',
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      );

  Widget _control(IconData icon, VoidCallback onPressed,
          {Color color = Colors.white24}) =>
      IconButton.filled(
          onPressed: onPressed,
          style: IconButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              fixedSize: const Size(50, 50)),
          icon: Icon(icon));
}
