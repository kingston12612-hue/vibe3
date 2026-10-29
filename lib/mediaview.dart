// Полноэкранные просмотрщики медиа: изображения и видео (данные приходят data:base64).
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'main.dart';

class ImageViewerPage extends StatelessWidget{
  final String mediaUrl;final String name;
  const ImageViewerPage({super.key,required this.mediaUrl,this.name=''});
  @override Widget build(BuildContext context){
    Uint8List bytes;
    try{bytes=mediaUrl.contains(',')?Uri.parse(mediaUrl).data!.contentAsBytes():Uint8List(0);}catch(_){bytes=Uint8List(0);}
    return Scaffold(
      backgroundColor:Colors.black,
      appBar:AppBar(backgroundColor:Colors.black,iconTheme:const IconThemeData(color:Colors.white),title:Text(name,style:const TextStyle(color:Colors.white,fontSize:15))),
      body:Center(child:bytes.isEmpty
        ?Text(S(context).mediaFailed,style:const TextStyle(color:Colors.white70))
        :InteractiveViewer(maxScale:5,child:Image.memory(bytes,fit:BoxFit.contain))),
    );
  }
}

class VideoViewerPage extends StatefulWidget{
  final String mediaUrl;final String name;
  const VideoViewerPage({super.key,required this.mediaUrl,this.name=''});
  @override State<VideoViewerPage> createState()=>_VideoViewerPageState();
}
class _VideoViewerPageState extends State<VideoViewerPage>{
  VideoPlayerController? vc;bool failed=false;
  @override void initState(){super.initState();_open();}
  Future<void> _open()async{
    try{
      final bytes=Uri.parse(widget.mediaUrl).data!.contentAsBytes();
      final dir=await Directory.systemTemp.createTemp('vibe');
      final f=File('${dir.path}/v.mp4');
      await f.writeAsBytes(bytes);
      final c=VideoPlayerController.file(f);
      await c.initialize();
      await c.play();
      if(mounted)setState(()=>vc=c);
      c.addListener((){if(mounted)setState(()=>{});});
    }catch(_){if(mounted)setState(()=>failed=true);}
  }
  @override void dispose(){vc?.dispose();super.dispose();}
  String _fmt(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  @override Widget build(BuildContext context){
    final c=vc;
    return Scaffold(
      backgroundColor:Colors.black,
      appBar:AppBar(backgroundColor:Colors.black,iconTheme:const IconThemeData(color:Colors.white),title:Text(widget.name,style:const TextStyle(color:Colors.white,fontSize:15))),
      body:failed||c==null
        ?Center(child:failed?Text(S(context).mediaFailed,style:const TextStyle(color:Colors.white70)):const CircularProgressIndicator(color:pink))
        :Column(children:[
          const Spacer(),
          AspectRatio(aspectRatio:c.value.aspectRatio==0?16/9:c.value.aspectRatio,child:VideoPlayer(c)),
          const Spacer(),
          Padding(padding:const EdgeInsets.fromLTRB(18,0,18,28),child:Column(children:[
            VideoProgressIndicator(c,allowScrubbing:true,colors:const VideoProgressColors(playedColor:pink,bufferedColor:Colors.white24,backgroundColor:Colors.white12)),
            const SizedBox(height:10),
            Row(children:[
              Text('${_fmt(c.value.position)} / ${_fmt(c.value.duration)}',style:const TextStyle(color:Colors.white70,fontSize:12)),
              const Spacer(),
              IconButton(onPressed:(){c.value.isPlaying?c.pause():c.play();if(mounted)setState(()=>{});},icon:Icon(c.value.isPlaying?Icons.pause_rounded:Icons.play_arrow_rounded,color:Colors.white,size:32)),
              const Spacer(),
              const SizedBox(width:60),
            ]),
          ])),
        ]),
    );
  }
}
