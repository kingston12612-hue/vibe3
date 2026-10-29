// Реальные звонки vibe<3: WebRTC (flutter_webrtc) + сигналинг через socket.io сервера.
// Исходящий: CallPage(outgoing). Входящий: Shell ловит 'call' и показывает IncomingScreen.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class CallStart{
  final String chatId,name,peerId;final bool video;
  CallStart({required this.chatId,required this.name,this.peerId='',required this.video});
}

class CallKit{
  static IO.Socket? _sock;
  static Future<IO.Socket>? _pending;
  static bool inCall=false;
  static Future<IO.Socket> socket(){
    final s=_sock;if(s!=null)return Future.value(s);
    return _pending??=_create();
  }
  static Future<IO.Socket> _create()async{
    final t=await Api.token();
    if(t==null)throw Exception('no_token');
    final p=IO.io(apiBase,IO.OptionBuilder().setTransports(['websocket']).setAuth({'token':t}).disableAutoConnect().build());
    p.connect();
    _sock=p;return p;
  }
  static Future<void> log(String chatId,bool video,String status,int dur)async{
    try{await Api.post('/calls',{'chatId':chatId,'video':video,'status':status,'duration':dur});}catch(_){}
  }
  // Отклонить входящий, когда уже звоним (или сокет не готов)
  static void busyReject(String to,String chatId){
    socket().then((s)=>s.emit('call:end',{'to':to,'chatId':chatId,'reason':'declined'})).catchError((_){});
  }
}

class CallPage extends StatefulWidget{
  final CallStart call;
  final Map<String,dynamic>? incomingOffer; // != null => входящий звонок
  const CallPage({super.key,required this.call,this.incomingOffer});
  @override State<CallPage> createState()=>_CallPageState();
}

class _CallPageState extends State<CallPage>{
  RTCPeerConnection? pc;MediaStream? localStream;
  final localRenderer=RTCVideoRenderer();final remoteRenderer=RTCVideoRenderer();
  IO.Socket? sock;
  String state='ringing';String peerId='';bool micOn=true,speakerOn=true;
  // ICE-кандидаты могут прийти раньше, чем создан pc (гонка при приёме звонка) — копим и применяем после
  final List<RTCIceCandidate> iceQueue=[];
  int seconds=0;Timer? ticker,timeout;
  bool get outgoing=>widget.incomingOffer==null;

  @override void initState(){
    super.initState();
    CallKit.inCall=true;
    WidgetsBinding.instance.addPostFrameCallback((_){_setup();});
  }
  @override void dispose(){_cleanup();super.dispose();}

  Future<void> _setup()async{
    final s=S(context);
    try{
      await localRenderer.initialize();await remoteRenderer.initialize();
      bool wantVideo=widget.call.video;
      MediaStream? ls;
      try{ls=await navigator.mediaDevices.getUserMedia({'audio':true,'video':wantVideo?{'facingMode':'user'}:false});}
      catch(_){if(wantVideo){wantVideo=false;try{ls=await navigator.mediaDevices.getUserMedia({'audio':true,'video':false});}catch(_){}}}
      if(ls==null||!mounted){_fail(s.callFailed);return;}
      localStream=ls;localRenderer.srcObject=ls;
      pc=await createPeerConnection(const{'iceServers':[{'urls':['stun:stun.l.google.com:19302','stun:stun1.l.google.com:19302']}],'sdpSemantics':'unified-plan'});
      for(final t in ls.getTracks()){pc!.addTrack(t,ls);}
      pc!.onIceCandidate=(c){if(c!=null&&sock!=null&&peerId.isNotEmpty){sock!.emit('call:ice',{'to':peerId,'chatId':widget.call.chatId,'candidate':c.toMap()});}};
      pc!.onTrack=(t){if(t.streams.isNotEmpty){remoteRenderer.srcObject=t.streams.first;if(mounted)setState(()=>{});}};
      pc!.onIceConnectionState=(st){
        if((st==RTCIceConnectionState.RTCIceConnectionStateConnected||st==RTCIceConnectionState.RTCIceConnectionStateCompleted)&&state!='active'){
          if(mounted)setState(()=>state='active');
          ticker?.cancel();
          ticker=Timer.periodic(const Duration(seconds:1),(_){if(mounted&&state=='active')setState(()=>seconds++);});
        }
        if(st==RTCIceConnectionState.RTCIceConnectionStateFailed)_hangup('ended',logIt:true,notifyPeer:false);
      };
      sock=await CallKit.socket();
      sock!.on('call:answer',_onAnswer);sock!.on('call:ice',_onIce);sock!.on('call:end',_onEnd);
      // применяем кандидаты, пришедшие до готовности pc
      for(final c in iceQueue){try{await pc!.addCandidate(c);}catch(_){}}
      iceQueue.clear();
      peerId=widget.call.peerId;
      if(peerId.isEmpty){try{final pr=await Api.get('/chats/'+widget.call.chatId+'/peer');peerId=(pr['id']??'').toString();}catch(_){}}
      if(peerId.isEmpty){_fail(s.callFailed);return;}
      if(!outgoing){
        final o=widget.incomingOffer!;
        await pc!.setRemoteDescription(RTCSessionDescription(o['sdp']??'',o['type']??'offer'));
        final ans=await pc!.createAnswer({'offerToReceiveAudio':1,'offerToReceiveVideo':wantVideo?1:0});
        await pc!.setLocalDescription(ans);
        sock!.emit('call:answer',{'to':peerId,'chatId':widget.call.chatId,'answer':{'type':ans.type,'sdp':ans.sdp}});
        if(mounted)setState(()=>state='connecting');
      }else{
        final p=await SharedPreferences.getInstance();
        final off=await pc!.createOffer({'offerToReceiveAudio':1,'offerToReceiveVideo':wantVideo?1:0});
        await pc!.setLocalDescription(off);
        sock!.emit('call',{'chatId':widget.call.chatId,'to':peerId,'name':(p.getString('name')??'').toString(),'video':wantVideo,'offer':{'type':off.type,'sdp':off.sdp}});
        if(mounted)setState(()=>state='ringing');
        timeout=Timer(const Duration(seconds:45),()=>_hangup('missed',logIt:true,notifyPeer:true));
      }
      if(mounted)setState(()=>{});
    }catch(e){_fail(e.toString());}
  }

  void _onAnswer(d){
    if(pc==null||state!='ringing'||d is! Map)return;
    timeout?.cancel();
    final a=d['answer'];
    if(a is Map&&a['sdp']!=null){
      pc?.setRemoteDescription(RTCSessionDescription(a['sdp'].toString(),a['type'].toString()=='answer'?'answer':a['type'].toString()));
      if(mounted)setState(()=>state='connecting');
    }
  }
  void _onIce(d){
    if(d is! Map||d['candidate'] is! Map)return;
    final c=d['candidate'];
    RTCIceCandidate cand;
    try{cand=RTCIceCandidate(c['candidate']?.toString(),c['sdpMid']?.toString(),c['sdpMLineIndex'] is int?c['sdpMLineIndex'] as int:int.tryParse('${c['sdpMLineIndex']}')??0);}catch(_){return;}
    if(pc==null){iceQueue.add(cand);return;} // pc ещё не готов — не падаем, применяем позже
    try{pc!.addCandidate(cand);}catch(_){}
  }
  void _onEnd(d){
    if(d is! Map)return;
    final reason=(d['reason']??'ended').toString();
    final status=state=='active'?'ended':(reason=='declined'?'declined':'missed');
    _hangup(status,logIt:outgoing,notifyPeer:false,reason:reason);
  }
  void _fail(String e){
    Api.debugLog('call fail: $e');
    _hangup('missed',logIt:outgoing,notifyPeer:false);
  }
  void _hangup(String status,{required bool logIt,required bool notifyPeer,String reason='hangup'}){
    if(!mounted)return;
    final s=S(context);
    timeout?.cancel();ticker?.cancel();
    if(notifyPeer&&sock!=null&&peerId.isNotEmpty){sock!.emit('call:end',{'to':peerId,'chatId':widget.call.chatId,'reason':reason});}
    if(logIt)CallKit.log(widget.call.chatId,widget.call.video,status,seconds);
    final show=status=='ended'?s.callEnded:(status=='declined'?s.declined:(status=='missed'?s.missedCall:s.callEnded));
    _cleanup();
    if(mounted){
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${widget.call.name} · $show')));
    }
  }
  void _cleanup(){
    timeout?.cancel();ticker?.cancel();
    try{sock?.off('call:answer',_onAnswer);sock?.off('call:ice',_onIce);sock?.off('call:end',_onEnd);}catch(_){}
    iceQueue.clear();
    try{pc?.close();}catch(_){}pc=null;
    try{localStream?.dispose();}catch(_){}localStream=null;
    try{localRenderer.dispose();}catch(_){}
    try{remoteRenderer.dispose();}catch(_){}
    CallKit.inCall=false;
  }
  void _toggleMic(){final on=!micOn;localStream?.getAudioTracks().forEach((t)=>t.enabled=on);if(mounted)setState(()=>micOn=on);}
  void _toggleSpeaker(){final on=!speakerOn;try{Helper.setSpeakerphoneOn(on);}catch(_){}if(mounted)setState(()=>speakerOn=on);}
  void _toggleCam(){final tracks=localStream?.getVideoTracks()??const<MediaStreamTrack>[];if(tracks.isEmpty)return;final on=!tracks.first.enabled;for(final t in tracks){t.enabled=on;}if(mounted)setState(()=>{});}

  String get clock=>'${(seconds~/60).toString().padLeft(2,'0')}:${(seconds%60).toString().padLeft(2,'0')}';
  String _statusText(AppStrings s){
    switch(state){
      case 'ringing':return s.ringing;
      case 'connecting':return s.connecting;
      case 'active':return clock;
      default:return s.connecting;
    }
  }

  @override Widget build(BuildContext context){
    final s=S(context);
    final hasRemote=remoteRenderer.srcObject!=null;
    final videoOn=widget.call.video&&(localStream?.getVideoTracks().isNotEmpty??false);
    return Scaffold(backgroundColor:bg,body:Stack(children:[
      // фон / удалённое видео
      Positioned.fill(child:Container(color:bg)),
      if(videoOn&&hasRemote)Positioned.fill(child:RTCVideoView(remoteRenderer,objectFit:RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
      if(!(videoOn&&hasRemote))...[
        const Positioned(top:-130,right:-90,child:_CGlow(size:300,color:Color(0x2E9B6BFF))),
        const Positioned(bottom:-150,left:-110,child:_CGlow(size:320,color:Color(0x2BE76BD0))),
      ],
      SafeArea(child:Column(children:[
        const SizedBox(height:26),
        Text(widget.call.name,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,letterSpacing:-.5),textAlign:TextAlign.center),
        const SizedBox(height:5),
        Text(_statusText(s),style:const TextStyle(color:muted,fontSize:15,fontWeight:FontWeight.w700,letterSpacing:2)),
        const SizedBox(height:8),
        Text(widget.call.video?s.videoCall:s.voiceCall,style:const TextStyle(color:muted,fontSize:12)),
        Expanded(
          child:videoOn&&hasRemote
            ?const SizedBox.shrink()
            :Center(child:_PulseAvatar(name:widget.call.name,active:state!='active')),
        ),
        // нижние контролы — все рабочие
        if(videoOn)Padding(
          padding:const EdgeInsets.fromLTRB(0,0,0,8),
          child:Text(videoOn&&!hasRemote?s.connecting:'',style:const TextStyle(color:muted,fontSize:11)),
        ),
        Padding(
          padding:const EdgeInsets.fromLTRB(24,0,24,10),
          child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
            _CallBtn(icon:micOn?Icons.mic_rounded:Icons.mic_off_rounded,label:micOn?(s.ru?'микрофон':'mic'):(s.ru?'выкл. звук':'muted'),dim:!micOn,onTap:_toggleMic),
            _CallBtn(icon:speakerOn?Icons.volume_up_rounded:Icons.volume_down_rounded,label:speakerOn?(s.ru?'динамик':'speaker'):(s.ru?'телефон':'handset'),dim:!speakerOn,onTap:_toggleSpeaker),
            if(videoOn)_CallBtn(icon:Icons.videocam_rounded,label:s.ru?'видео':'video',dim:false,onTap:_toggleCam),
          ]),
        ),
        Padding(
          padding:const EdgeInsets.fromLTRB(24,4,24,26),
          child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
            const SizedBox(width:76),
            Container(
              width:76,height:76,
              decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFFF5A6E),Color(0xFFE7445B)]),shape:BoxShape.circle,boxShadow:[BoxShadow(color:const Color(0xFFE7445B).withOpacity(.45),blurRadius:26,offset:const Offset(0,8))]),
              child:Material(color:Colors.transparent,child:InkWell(customBorder:const CircleBorder(),onTap:()=>_hangup(state=='active'?'ended':'missed',logIt:outgoing,notifyPeer:true,reason:state=='active'?'hangup':'declined'),child:const Center(child:Icon(Icons.call_end_rounded,color:Colors.white,size:32)))),
            ),
            const SizedBox(width:76),
          ]),
        ),
      ])),
      // локальное видео — картинка в картинке
      if(videoOn&&localRenderer.srcObject!=null)Positioned(
        top:70,right:16,
        child:ClipRRect(
          borderRadius:BorderRadius.circular(14),
          child:Container(width:104,height:150,color:surface2,child:RTCVideoView(localRenderer,mirror:true,objectFit:RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
        ),
      ),
    ]));
  }
}

// --- Входящий звонок ---
class IncomingScreen extends StatefulWidget{
  final Map<String,dynamic> data;final VoidCallback onClosed;
  const IncomingScreen({super.key,required this.data,required this.onClosed});
  @override State<IncomingScreen> createState()=>_IncomingScreenState();
}
class _IncomingScreenState extends State<IncomingScreen> with SingleTickerProviderStateMixin{
  late final AnimationController pulse;
  late final Timer ring;
  bool busy=false;
  @override void initState(){
    super.initState();
    pulse=AnimationController(vsync:this,duration:const Duration(milliseconds:1100))..repeat(reverse:true);
    ring=Timer.periodic(const Duration(milliseconds:1700),(_){SystemSound.play(SystemSoundType.alert);HapticFeedback.mediumImpact();});
    SystemSound.play(SystemSoundType.alert);
  }
  @override void dispose(){pulse.dispose();ring.cancel();super.dispose();}
  Future<void> _accept()async{
    if(busy)return;busy=true;
    final d=widget.data;
    if(mounted)Navigator.of(context).pop(); // убрать диалог входящего
    widget.onClosed();
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>CallPage(
      call:CallStart(chatId:(d['chatId']??'').toString(),name:(d['name']??'').toString(),peerId:(d['from']??'').toString(),video:d['video']==true),
      incomingOffer:(d['offer'] as Map?)?.cast<String,dynamic>(),
    )));
  }
  void _decline(){
    final d=widget.data;
    CallKit.busyReject((d['from']??'').toString(),(d['chatId']??'').toString());
    Navigator.of(context).pop();
    widget.onClosed();
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    final d=widget.data;
    return Dialog.fullscreen(
      backgroundColor:bg,
      child:Stack(children:[
        const Positioned(top:-130,right:-90,child:_CGlow(size:300,color:Color(0x2E9B6BFF))),
        const Positioned(bottom:-150,left:-110,child:_CGlow(size:320,color:Color(0x2BE76BD0))),
        SafeArea(child:Column(children:[
          const SizedBox(height:52),
          Text(s.incomingCall,style:const TextStyle(color:muted,fontSize:13,fontWeight:FontWeight.w800,letterSpacing:1.5)),
          const SizedBox(height:28),
          AnimatedBuilder(animation:pulse,builder:(context,_)=>Container(
            width:170+pulse.value*22,height:170+pulse.value*22,
            decoration:BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),boxShadow:[BoxShadow(color:pink.withOpacity(.30+pulse.value*.25),blurRadius:40,spreadRadius:8)]),
            child:Padding(padding:const EdgeInsets.all(5),child:CircleAvatar(radius:80,backgroundColor:bg,child:ClipOval(child:Avatar(name:(d['name']??'?').toString(),size:150)))),
          )),
          const Spacer(),
          Text((d['name']??'?').toString(),style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900),textAlign:TextAlign.center),
          const SizedBox(height:6),
          Text(d['video']==true?s.videoCall:s.voiceCall,style:const TextStyle(color:muted,fontSize:14)),
          const SizedBox(height:46),
          Padding(
            padding:const EdgeInsets.fromLTRB(30,0,30,40),
            child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
              Column(mainAxisSize:MainAxisSize.min,children:[
                Container(width:68,height:68,decoration:BoxDecoration(color:surface2.withOpacity(.9),shape:BoxShape.circle,border:Border.all(color:stroke)),child:Material(color:Colors.transparent,child:InkWell(customBorder:const CircleBorder(),onTap:_decline,child:const Center(child:Icon(Icons.call_end_rounded,color:Color(0xFFFF5A6E),size:28))))),
                const SizedBox(height:7),Text(s.decline,style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.w700)),
              ]),
              Column(mainAxisSize:MainAxisSize.min,children:[
                Container(width:68,height:68,decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF59E391),Color(0xFF2FBF71)]),shape:BoxShape.circle,boxShadow:[BoxShadow(color:green.withOpacity(.4),blurRadius:22,offset:const Offset(0,6))]),child:Material(color:Colors.transparent,child:InkWell(customBorder:const CircleBorder(),onTap:_accept,child:const Center(child:Icon(Icons.call_rounded,color:Colors.white,size:28))))),
                const SizedBox(height:7),Text(s.accept,style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.w700)),
              ]),
            ]),
          ),
        ])),
      ]),
    );
  }
}

class _CallBtn extends StatelessWidget{
  final IconData icon;final String label;final bool dim;final VoidCallback onTap;
  const _CallBtn({required this.icon,required this.label,required this.onTap,this.dim=false});
  @override Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    Container(
      width:62,height:62,
      decoration:BoxDecoration(color:dim?surface2.withOpacity(.55):surface2.withOpacity(.85),shape:BoxShape.circle,border:Border.all(color:stroke)),
      child:Material(color:Colors.transparent,child:InkWell(customBorder:const CircleBorder(),onTap:onTap,child:Center(child:Icon(icon,color:dim?muted:Colors.white,size:24)))),
    ),
    const SizedBox(height:7),
    Text(label,style:const TextStyle(color:muted,fontSize:10.5,fontWeight:FontWeight.w700)),
  ]);
}

class _PulseAvatar extends StatefulWidget{
  final String name;final bool active;
  const _PulseAvatar({required this.name,required this.active});
  @override State<_PulseAvatar> createState()=>_PulseAvatarState();
}
class _PulseAvatarState extends State<_PulseAvatar> with SingleTickerProviderStateMixin{
  late final AnimationController c;
  @override void initState(){super.initState();c=AnimationController(vsync:this,duration:const Duration(milliseconds:1400));if(widget.active)c.repeat(reverse:true);}
  @override void didUpdateWidget(covariant _PulseAvatar old){super.didUpdateWidget(old);if(widget.active&&!c.isAnimating)c.repeat(reverse:true);if(!widget.active)c.stop();}
  @override void dispose(){c.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:c,builder:(context,_){
    final k=widget.active?c.value:0;
    return Container(
      width:200+k*24,height:200+k*24,
      decoration:BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),boxShadow:[BoxShadow(color:pink.withOpacity(.25+k*.2),blurRadius:40,spreadRadius:6)]),
      child:Padding(padding:const EdgeInsets.all(6),child:CircleAvatar(radius:95,backgroundColor:bg,child:ClipOval(child:Avatar(name:widget.name,size:170)))),
    );
  });
}

class _CGlow extends StatelessWidget{
  final double size;final Color color;const _CGlow({required this.size,required this.color});
  @override Widget build(BuildContext context)=>IgnorePointer(child:Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle,color:color,boxShadow:[BoxShadow(color:color,blurRadius:90,spreadRadius:30)])));
}
