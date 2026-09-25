import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bg=Color(0xFF09090F), surface=Color(0xFF14141D), surface2=Color(0xFF1A1A26), stroke=Color(0xFF292938);
const muted=Color(0xFF9696AC), purple=Color(0xFF8164FF), blue=Color(0xFF63A8FF), pink=Color(0xFFD96EFF);

void main()=>runApp(const VibeApp());

class VibeApp extends StatefulWidget{const VibeApp({super.key});@override State<VibeApp> createState()=>_VibeState();}
class _VibeState extends State<VibeApp>{
 bool light=false,ready=false;String name='Alex';
 @override void initState(){super.initState();load();}
 Future<void> load()async{final p=await SharedPreferences.getInstance();setState((){light=p.getBool('light')??false;name=p.getString('name')??'Alex';ready=true;});}
 Future<void> theme(bool v)async{final p=await SharedPreferences.getInstance();await p.setBool('light',v);setState(()=>light=v);}
 Future<void> rename(String v)async{final p=await SharedPreferences.getInstance();await p.setString('name',v);setState(()=>name=v);}
 @override Widget build(BuildContext c){if(!ready)return const MaterialApp(home:Scaffold(backgroundColor:bg,body:Center(child:CircularProgressIndicator())));
 return MaterialApp(debugShowCheckedModeBanner:false,title:'vibe<3',themeMode:light?ThemeMode.light:ThemeMode.dark,darkTheme:themeData(true),theme:themeData(false),
 home:Shell(name:name,light:light,onTheme:theme,onName:rename));}
}
ThemeData themeData(bool dark)=>ThemeData(brightness:dark?Brightness.dark:Brightness.light,scaffoldBackgroundColor:dark?bg:const Color(0xFFF7F7FB),useMaterial3:true,
 colorScheme:ColorScheme.fromSeed(seedColor:purple,brightness:dark?Brightness.dark:Brightness.light),
 appBarTheme:AppBarTheme(backgroundColor:dark?bg:const Color(0xFFF7F7FB),elevation:0),
 navigationBarTheme:NavigationBarThemeData(backgroundColor:dark?surface:Colors.white),
 inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:dark?surface2:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide(color:dark?stroke:Colors.black12)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:const BorderSide(color:purple))));

class Chat{String id,name,preview,time;bool online;int unread;Chat(this.id,this.name,this.preview,this.time,{this.online=false,this.unread=0});}
class Msg{String text;bool mine;Msg(this.text,this.mine);}
final chats=<Chat>[Chat('1','Marcus','yo, are you online?','02:14',online:true,unread:2),Chat('2','Lina','That photo is insane 🔥','01:48',online:true),Chat('3','vibe<3 Team','Welcome to the new vibe.','Yesterday'),Chat('4','Mike','See you tomorrow','Yesterday')];

class Shell extends StatefulWidget{final String name;final bool light;final ValueChanged<bool> onTheme;final ValueChanged<String> onName;
 const Shell({super.key,required this.name,required this.light,required this.onTheme,required this.onName});@override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell>{int tab=0;
 @override Widget build(BuildContext c){final pages=[Chats(onOpen:(x)=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ChatPage(chat:x))),),Contacts(onOpen:(n)=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ChatPage(chat:Chat('x',n,'New chat','now',online:true))))),const Calls(),Settings(name:widget.name,light:widget.light,onTheme:widget.onTheme,onName:widget.onName)];
 return Scaffold(body:SafeArea(child:IndexedStack(index:tab,children:pages)),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
 NavigationDestination(icon:Icon(Icons.chat_bubble_outline),selectedIcon:Icon(Icons.chat_bubble),label:'Chats'),
 NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'Contacts'),
 NavigationDestination(icon:Icon(Icons.call_outlined),selectedIcon:Icon(Icons.call),label:'Calls'),
 NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'Settings') ]));}}

class Chats extends StatefulWidget{final ValueChanged<Chat> onOpen;const Chats({super.key,required this.onOpen});@override State<Chats> createState()=>_ChatsState();}
class _ChatsState extends State<Chats>{String q='';
 @override Widget build(BuildContext c){final list=chats.where((x)=>x.name.toLowerCase().contains(q.toLowerCase())||x.preview.toLowerCase().contains(q.toLowerCase())).toList();
 return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(20,12,20,8),child:Row(children:[const Expanded(child:Text('vibe<3',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>showSearch(context:context,delegate:ChatSearch()),icon:const Icon(Icons.search)),IconButton(onPressed:()=>showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>const NewChat()),icon:const Icon(Icons.edit))])),
 Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search chats',contentPadding:EdgeInsets.symmetric(vertical:0)))),
 Expanded(child:ListView.separated(padding:const EdgeInsets.all(12),itemCount:list.length,itemBuilder:(_,i)=>Tile(chat:list[i],tap:()=>widget.onOpen(list[i])),separatorBuilder:(_,__)=>const SizedBox(height:6))) ]);}}
class ChatSearch extends SearchDelegate<Chat?>{ @override List<Widget>? buildActions(BuildContext c)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear))];@override Widget buildLeading(BuildContext c)=>IconButton(onPressed:()=>close(c,null),icon:const Icon(Icons.arrow_back));@override Widget buildResults(BuildContext c)=>r(c);@override Widget buildSuggestions(BuildContext c)=>r(c);Widget r(BuildContext c){final q=query.toLowerCase();return ListView(children:chats.where((x)=>x.name.toLowerCase().contains(q)).map((x)=>ListTile(leading:Avatar(name:x.name),title:Text(x.name),subtitle:Text(x.preview),onTap:()=>close(c,x))).toList());}}
class Tile extends StatelessWidget{
 final Chat chat; final VoidCallback tap;
 const Tile({super.key,required this.chat,required this.tap});
 @override Widget build(BuildContext c){
  return Card(
   color:Theme.of(c).brightness==Brightness.dark?surface:Colors.white,
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
   child:ListTile(
    onTap:tap,
    contentPadding:const EdgeInsets.all(10),
    leading:Avatar(name:chat.name,size:54),
    title:Text(chat.name,style:const TextStyle(fontWeight:FontWeight.w800)),
    subtitle:Text(chat.preview,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted)),
    trailing:Column(
     mainAxisAlignment:MainAxisAlignment.center,
     children:[
      Text(chat.time,style:const TextStyle(color:muted,fontSize:12)),
      if(chat.unread>0) Container(
       margin:const EdgeInsets.only(top:5),
       padding:const EdgeInsets.symmetric(horizontal:7,vertical:2),
       decoration:BoxDecoration(color:pink,borderRadius:BorderRadius.circular(10)),
       child:Text(chat.unread.toString(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
      ),
     ],
    ),
   ),
  );
 }
}
class Avatar extends StatelessWidget{final String name;final double size;const Avatar({super.key,required this.name,this.size=46});@override Widget build(BuildContext c){final a=[purple,pink,blue,Color(0xFF43D6B5)];final i=name.isEmpty?0:name.codeUnitAt(0)%4;return Container(width:size,height:size,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[a[i],a[(i+1)%4]])),child:Text(name.isEmpty?'?':name[0].toUpperCase(),style:TextStyle(color:Colors.white,fontSize:size*.38,fontWeight:FontWeight.w900)));}}

class ChatPage extends StatefulWidget{final Chat chat;const ChatPage({super.key,required this.chat});@override State<ChatPage> createState()=>_ChatState();}
class _ChatState extends State<ChatPage>{final input=TextEditingController();final scroll=ScrollController();final msgs=<Msg>[Msg('hey! 👋',false),Msg('yo! welcome to vibe<3',true),Msg('this feels clean already',false)];
 void send(){final s=input.text.trim();if(s.isEmpty)return;setState((){msgs.add(Msg(s,true));widget.chat.preview=s;widget.chat.time='now';});input.clear();}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Row(children:[Avatar(name:widget.chat.name,size:40),const SizedBox(width:9),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.chat.name,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),Text(widget.chat.online?'online':'last seen recently',style:const TextStyle(fontSize:11,color:muted))])]),actions:[IconButton(onPressed:(){},icon:const Icon(Icons.call_outlined)),IconButton(onPressed:(){},icon:const Icon(Icons.more_vert))]),body:Column(children:[Expanded(child:ListView.builder(controller:scroll,padding:const EdgeInsets.all(16),itemCount:msgs.length,itemBuilder:(_,i)=>Bubble(msg:msgs[i]))),SafeArea(top:false,child:Row(children:[IconButton(onPressed:()=>showModalBottomSheet(context:c,showDragHandle:true,builder:(_)=>const Attach()),icon:const Icon(Icons.add_circle_outline)),Expanded(child:TextField(controller:input,maxLines:5,decoration:const InputDecoration(hintText:'Message...',contentPadding:EdgeInsets.symmetric(horizontal:16,vertical:12))),),const SizedBox(width:6),Padding(padding:const EdgeInsets.only(right:8,bottom:6),child:FloatingActionButton(onPressed:send,mini:true,child:const Icon(Icons.arrow_upward))) ]))]));}
class Bubble extends StatelessWidget{
 final Msg msg; const Bubble({super.key,required this.msg});
 @override Widget build(BuildContext c){
  return Align(
   alignment:msg.mine?Alignment.centerRight:Alignment.centerLeft,
   child:Container(
    constraints:const BoxConstraints(maxWidth:320),
    margin:const EdgeInsets.only(bottom:8),
    padding:const EdgeInsets.symmetric(horizontal:15,vertical:11),
    decoration:BoxDecoration(
     color:msg.mine?purple:(Theme.of(c).brightness==Brightness.dark?surface2:Colors.white),
     borderRadius:BorderRadius.circular(18),
    ),
    child:Text(msg.text,style:TextStyle(color:msg.mine?Colors.white:null,fontSize:15)),
   ),
  );
 }
}
class Attach extends StatelessWidget{const Attach({super.key});@override Widget build(BuildContext c)=>SafeArea(child:Wrap(children:const[ ListTile(leading:Icon(Icons.photo_outlined),title:Text('Photo / video')),ListTile(leading:Icon(Icons.mic_none),title:Text('Voice message')),ListTile(leading:Icon(Icons.insert_drive_file_outlined),title:Text('File')),SizedBox(height:10)]));}

class Contacts extends StatefulWidget{final ValueChanged<String> onOpen;const Contacts({super.key,required this.onOpen});@override State<Contacts> createState()=>_ContactsState();}
class _ContactsState extends State<Contacts>{
 String q='';
 final people=['Marcus','Lina','Mike','Sophie','Noah','Emma','Daniel'];
 @override Widget build(BuildContext c){
  final p=people.where((x)=>x.toLowerCase().contains(q.toLowerCase())).toList();
  return Column(
   children:[
    const Padding(
     padding:EdgeInsets.fromLTRB(20,18,20,12),
     child:Align(alignment:Alignment.centerLeft,child:Text('Contacts',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900))),
    ),
    Padding(
     padding:const EdgeInsets.symmetric(horizontal:16),
     child:TextField(
      onChanged:(v)=>setState(()=>q=v),
      decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Find people'),
     ),
    ),
    Expanded(
     child:ListView.builder(
      itemCount:p.length,
      itemBuilder:(_,i)=>ListTile(
       contentPadding:const EdgeInsets.symmetric(horizontal:20,vertical:3),
       leading:Avatar(name:p[i]),
       title:Text(p[i],style:const TextStyle(fontWeight:FontWeight.w700)),
       subtitle:const Text('Available',style:TextStyle(color:muted)),
       onTap:()=>widget.onOpen(p[i]),
      ),
     ),
    ),
   ],
  );
 }
}
class Calls extends StatelessWidget{const Calls({super.key});@override Widget build(BuildContext c)=>Column(children:[const Padding(padding:EdgeInsets.fromLTRB(20,18,20,12),child:Align(alignment:Alignment.centerLeft,child:Text('Calls',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)))),Expanded(child:ListView(children:[call('Marcus','Today, 01:24',false),call('Lina','Yesterday, 22:18',false),call('Mike','Sep 24, 19:42',true)]))]);Widget call(String n,String t,bool missed)=>ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:20,vertical:5),leading:Avatar(name:n),title:Text(n,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(t,style:const TextStyle(color:muted)),trailing:Icon(missed?Icons.call_received:Icons.call_outlined,color:missed?pink:null));}

class Settings extends StatelessWidget{final String name;final bool light;final ValueChanged<bool> onTheme;final ValueChanged<String> onName;const Settings({super.key,required this.name,required this.light,required this.onTheme,required this.onName});
 @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(18),children:[const Text('Settings',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:18),Card(color:Theme.of(c).brightness==Brightness.dark?surface:Colors.white,child:ListTile(contentPadding:const EdgeInsets.all(12),leading:Avatar(name:name,size:56),title:Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('@vibe_user',style:TextStyle(color:muted)),onTap:()=>edit(c))),const SizedBox(height:10),Card(color:Theme.of(c).brightness==Brightness.dark?surface:Colors.white,child:SwitchListTile(value:!light,onChanged:(v)=>onTheme(!v),secondary:const Icon(Icons.dark_mode_outlined),title:const Text('Dark Y2K theme'),subtitle:const Text('Purple / blue / pink',style:TextStyle(color:muted)))),section(c,'Privacy & security',[row(Icons.lock_outline,'Privacy','Last seen and read receipts'),row(Icons.shield_outlined,'Encryption','Secure message architecture')]),section(c,'Notifications',[row(Icons.notifications_none,'Notifications','Messages and calls')]),section(c,'About',[row(Icons.info_outline,'About vibe<3','Version 1.0.0')])]);Widget section(BuildContext c,String t,List<Widget> x)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.fromLTRB(4,18,4,7),child:Text(t.toUpperCase(),style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.1))),Card(color:Theme.of(c).brightness==Brightness.dark?surface:Colors.white,child:Column(children:x))]);Widget row(IconData i,String t,String s)=>ListTile(leading:Icon(i),title:Text(t,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(s,style:const TextStyle(color:muted,fontSize:12)),trailing:const Icon(Icons.chevron_right));void edit(BuildContext c){final x=TextEditingController(text:name);showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Edit profile'),content:TextField(controller:x),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:(){onName(x.text.trim().isEmpty?'Alex':x.text.trim());Navigator.pop(c);},child:const Text('Save'))]));}}
class NewChat extends StatelessWidget{const NewChat({super.key});@override Widget build(BuildContext c)=>SafeArea(child:Wrap(children:const[Padding(padding:EdgeInsets.all(20),child:Text('New chat',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900))),ListTile(leading:Icon(Icons.person_add_alt_1),title:Text('New contact')),ListTile(leading:Icon(Icons.group_add_outlined),title:Text('New group')),ListTile(leading:Icon(Icons.qr_code_2),title:Text('Scan QR')),SizedBox(height:12)]));}
