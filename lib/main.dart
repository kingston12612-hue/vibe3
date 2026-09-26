import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

const apiBase=String.fromEnvironment('VIBE_API',defaultValue:'https://vibe-api-production-7f4a.up.railway.app');
const bg=Color(0xFF09090F),surface=Color(0xFF14141D),surface2=Color(0xFF1A1A26),stroke=Color(0xFF292938),green=Color(0xFF59E391);
const muted=Color(0xFF9696AC),purple=Color(0xFF8164FF),blue=Color(0xFF63A8FF),pink=Color(0xFFD96EFF);

void main()=>runApp(const VibeApp());

class Api{
 static Future<String?> token()async=>(await SharedPreferences.getInstance()).getString('token');
 static Future<Map<String,String>> headers()async{final t=await token();return {'Content-Type':'application/json',if(t!=null)'Authorization':'Bearer $t'};}
 static Future<dynamic> get(String path)async{final r=await http.get(Uri.parse('$apiBase$path'),headers:await headers()).timeout(const Duration(seconds:15));if(r.statusCode<200||r.statusCode>=300)throw Exception('http_${r.statusCode}');return jsonDecode(r.body);}
 static Future<dynamic> post(String path,Map<String,dynamic> body)async{try{final r=await http.post(Uri.parse('$apiBase$path'),headers:await headers(),body:jsonEncode(body)).timeout(const Duration(seconds:15));dynamic d;try{d=jsonDecode(r.body);}catch(_){d={};}if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map&&d['error']!=null?'${d['error']}:http_${r.statusCode}':'http_${r.statusCode}');return d;}catch(e){rethrow;}}
 static Future<dynamic> put(String path,Map<String,dynamic> body)async{try{final r=await http.put(Uri.parse('$apiBase$path'),headers:await headers(),body:jsonEncode(body)).timeout(const Duration(seconds:15));dynamic d;try{d=jsonDecode(r.body);}catch(_){d={};}if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map&&d['error']!=null?'${d['error']}:http_${r.statusCode}':'http_${r.statusCode}');return d;}catch(e){rethrow;}}
}


class AppStrings {
  final bool ru;
  const AppStrings(this.ru);
  String get chats=>ru?'Чаты':'Chats';
  String get people=>ru?'Люди':'People';
  String get calls=>ru?'Звонки':'Calls';
  String get settings=>ru?'Настройки':'Settings';
  String get search=>ru?'Поиск':'Search';
  String get searchChats=>ru?'Поиск по чатам':'Search chats';
  String get newChat=>ru?'Новый чат':'New chat';
  String get noChats=>ru?'Пока нет чатов':'No chats yet';
  String get noChatsSub=>ru?'Найди человека и начни разговор.':'Find someone and start a conversation.';
  String get noPeople=>ru?'Ничего не найдено':'No people found';
  String get noPeopleSub=>ru?'Попробуй имя или @username.':'Try a name or @username.';
  String get findPeopleHint=>ru?'Имя или @username':'Name or @username';
  String get messageHint=>ru?'Сообщение...':'Message...';
  String get online=>ru?'онлайн':'online';
  String get active=>ru?'на vibe<3':'on vibe<3';
  String get profile=>ru?'Профиль':'Profile';
  String get editProfile=>ru?'Редактировать профиль':'Edit profile';
  String get name=>ru?'Имя':'Name';
  String get username=>'Username';
  String get save=>ru?'Сохранить':'Save';
  String get cancel=>ru?'Отмена':'Cancel';
  String get ok=>ru?'Готово':'Done';
  String get darkY2K=>'Dark Y2K';
  String get darkY2KSub=>ru?'Тёмный интерфейс с мягким неоном':'Dark interface with soft neon';
  String get language=>ru?'Язык':'Language';
  String get russian=>'Русский';
  String get english=>'English';
  String get privacy=>ru?'Приватность':'Privacy';
  String get privacySub=>ru?'Статусы и прочитанные сообщения':'Presence and read status';
  String get security=>ru?'Безопасность':'Security';
  String get securitySub=>ru?'Авторизация и защита аккаунта':'Account authentication';
  String get notifications=>ru?'Уведомления':'Notifications';
  String get notificationsOn=>ru?'Включены':'Enabled';
  String get notificationsOff=>ru?'Выключены':'Disabled';
  String get about=>ru?'О приложении':'About';
  String get version=>'v1.0.0';
  String get signOut=>ru?'Выйти':'Sign out';
  String get createAccount=>ru?'Создать аккаунт':'Create account';
  String get welcomeBack=>ru?'С возвращением':'Welcome back';
  String get joinVibe=>ru?'Добро пожаловать в vibe<3':'Welcome to vibe<3';
  String get signIn=>ru?'Войти':'Sign in';
  String get signInContinue=>ru?'Войди, чтобы продолжить':'Sign in to continue';
  String get alreadyHave=>ru?'Уже есть аккаунт? Войти':'Already have an account? Sign in';
  String get newToVibe=>ru?'Новый в vibe<3? Создать аккаунт':'New to vibe<3? Create account';
  String get email=>'Email';
  String get password=>ru?'Пароль':'Password';
  String get repeatPassword=>ru?'Повтори пароль':'Repeat password';
  String get nameHint=>ru?'Твоё имя':'Your name';
  String get usernameHint=>'username_123';
  String get wait=>ru?'Подожди...':'Please wait...';
  String get callsNext=>ru?'Звонки уже рядом':'Calls are coming';
  String get callsSub=>ru?'Экран звонка уже готов. Голос и видео подключим следующим этапом.':'The call screen is ready. Voice and video transport comes next.';
  String get voiceCall=>ru?'Голосовой звонок':'Voice call';
  String get videoCall=>ru?'Видеозвонок':'Video call';
  String get callConnect=>ru?'Подключаем соединение':'Connecting the call';
  String get endCall=>ru?'Завершить':'End call';
  String get refresh=>ru?'Обновить':'Refresh';
  String get chooseLanguage=>ru?'Выбери язык':'Choose language';
  String get aboutBody=>ru?'vibe<3 — тёмный Y2K-мессенджер. Аккаунты и личные чаты подключены к серверу.':'vibe<3 — a dark Y2K messenger. Accounts and direct chats are connected to the server.';
  String get privacyBody=>ru?'Здесь уже есть экран настроек. Полные статусы и read receipts подключим отдельным backend-модулем.':'This settings screen is active. Full presence and read receipts will be connected by a dedicated backend module.';
  String get securityBody=>ru?'Вход защищён серверной JWT-сессией, профиль хранится на сервере.':'Login is protected by a server-side JWT session and profile data is stored on the server.';
  String get openChatError=>ru?'Не удалось открыть чат':'Could not open the chat';
  String get messageNotSent=>ru?'Сообщение не отправлено':'Message was not sent';
  String get connectionError=>ru?'Нет соединения с сервером vibe<3':'Cannot connect to the vibe<3 server';
  String get profileSaveError=>ru?'Не удалось сохранить профиль':'Could not save the profile';
  String get invalidUsername=>ru?'Неверный username':'Invalid username';
  String get usernameTaken=>ru?'Этот username уже занят':'That username is already taken';
  String get emailExists=>ru?'Этот email уже зарегистрирован':'That email is already registered';
  String get invalidCredentials=>ru?'Неверный email или пароль':'Invalid email or password';
  String get emailInvalid=>ru?'Введи корректный email':'Enter a valid email';
  String get passwordShort=>ru?'Пароль — минимум 6 символов':'Password must be at least 6 characters';
  String get nameRequired=>ru?'Введи имя':'Enter your name';
  String get usernameRules=>ru?'3–30 символов: a-z, 0-9, _':'3–30 chars: a-z, 0-9, _';
  String get passwordsMismatch=>ru?'Пароли не совпадают':'Passwords do not match';
  String get profileCheck=>ru?'Проверь имя и username':'Check name and username';
  String get mediaNext=>ru?'Медиа-отправка будет подключена следующим этапом.':'Media sending will be connected next.';
}

AppStrings S(BuildContext c)=>AppStrings(Localizations.localeOf(c).languageCode=='ru');

ThemeData vibeTheme(bool dark){
  final base=ThemeData(useMaterial3:true,brightness:dark?Brightness.dark:Brightness.light,colorScheme:ColorScheme.fromSeed(seedColor:purple,brightness:dark?Brightness.dark:Brightness.light));
  return base.copyWith(
    scaffoldBackgroundColor:dark?bg:const Color(0xFFF6F4FB),
    canvasColor:dark?bg:const Color(0xFFF6F4FB),
    appBarTheme:AppBarTheme(backgroundColor:(dark?bg:const Color(0xFFF6F4FB)).withOpacity(.96),elevation:0,surfaceTintColor:Colors.transparent),
    cardTheme:CardTheme(color:dark?surface:Colors.white,elevation:0,margin:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:BorderSide(color:dark?stroke:Colors.black12))),
    navigationBarTheme:NavigationBarThemeData(backgroundColor:dark?const Color(0xFF0D0D13):Colors.white,indicatorColor:purple.withOpacity(.18),height:72,labelTextStyle:WidgetStatePropertyAll(const TextStyle(fontSize:11,fontWeight:FontWeight.w800))),
    inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:dark?surface2:const Color(0xFFEFEFF5),hintStyle:TextStyle(color:dark?muted:const Color(0xFF7E7E8E)),border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide(color:dark?stroke:Colors.black12)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide(color:dark?stroke:Colors.black12)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:const BorderSide(color:purple,width:1.4))),
    filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),minimumSize:const Size.fromHeight(52))),
    snackBarTheme:SnackBarThemeData(behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
  );
}

class VibeApp extends StatefulWidget{const VibeApp({super.key});@override State<VibeApp> createState()=>_VibeState();}
class _VibeState extends State<VibeApp>{
  bool ready=false,logged=false,light=false,notifications=true;
  String language='en',name='Alex',email='',username='';
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    final p=await SharedPreferences.getInstance();
    final systemLang=WidgetsBinding.instance.platformDispatcher.locale.languageCode=='ru'?'ru':'en';
    setState((){
      language=p.getString('language')??systemLang;
      light=p.getBool('light')??false;
      notifications=p.getBool('notifications')??true;
      name=p.getString('name')??'Alex';
      email=p.getString('email')??'';
      username=p.getString('username')??'';
      logged=p.getString('token')!=null;
      ready=true;
    });
  }
  Future<void> saveUser(String e,String n,String t)async{
    final p=await SharedPreferences.getInstance();
    await p.setString('token',t);await p.setString('email',e);await p.setString('name',n);
    final me=await Api.get('/me');final u=(me['username']??'').toString();
    await p.setString('username',u);
    setState((){logged=true;email=e;name=n;username=u;});
  }
  Future<void> setTheme(bool v)async{final p=await SharedPreferences.getInstance();await p.setBool('light',v);setState(()=>light=v);}
  Future<void> setLanguage(String v)async{final p=await SharedPreferences.getInstance();await p.setString('language',v);setState(()=>language=v);}
  Future<void> setNotifications(bool v)async{final p=await SharedPreferences.getInstance();await p.setBool('notifications',v);setState(()=>notifications=v);}
  Future<void> updateProfile(String n,String u)async{
    final d=await Api.put('/me',{'name':n,'username':u});
    final p=await SharedPreferences.getInstance();
    final nn=(d['display_name']??n).toString();final uu=(d['username']??u).toString();
    await p.setString('name',nn);await p.setString('username',uu);
    setState((){name=nn;username=uu;});
  }
  Future<void> logout()async{final p=await SharedPreferences.getInstance();await p.remove('token');setState(()=>logged=false);}
  @override Widget build(BuildContext context){
    if(!ready)return MaterialApp(debugShowCheckedModeBanner:false,theme:vibeTheme(true),home:const Scaffold(body:Center(child:CircularProgressIndicator())));
    return MaterialApp(debugShowCheckedModeBanner:false,title:'vibe<3',locale:Locale(language),supportedLocales:const[Locale('en'),Locale('ru')],themeMode:light?ThemeMode.light:ThemeMode.dark,theme:vibeTheme(false),darkTheme:vibeTheme(true),home:logged?Shell(name:name,username:username,light:light,language:language,notifications:notifications,onTheme:setTheme,onLanguage:setLanguage,onNotifications:setNotifications,onProfile:updateProfile,onLogout:logout):AuthScreen(onLogin:saveUser));
  }
}

class AuthScreen extends StatefulWidget{
  final Future<void> Function(String,String,String) onLogin;
  const AuthScreen({super.key,required this.onLogin});
  @override State<AuthScreen> createState()=>_AuthState();
}
class _AuthState extends State<AuthScreen>{
  bool register=false,busy=false,show1=false,show2=false;
  final email=TextEditingController(),name=TextEditingController(),username=TextEditingController(),pass=TextEditingController(),pass2=TextEditingController();
  @override void dispose(){email.dispose();name.dispose();username.dispose();pass.dispose();pass2.dispose();super.dispose();}
  void snack(String x)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));
  Future<void> submit()async{
    final s=S(context);final e=email.text.trim().toLowerCase();final pw=pass.text;final n=name.text.trim();final u=username.text.trim().toLowerCase().replaceFirst('@','');
    if(!e.contains('@')||!e.contains('.')){snack(s.emailInvalid);return;}
    if(pw.length<6){snack(s.passwordShort);return;}
    if(register&&n.length<2){snack(s.nameRequired);return;}
    if(register&&!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(u)){snack(s.usernameRules);return;}
    if(register&&pass2.text!=pw){snack(s.passwordsMismatch);return;}
    setState(()=>busy=true);
    try{
      final d=await Api.post('/auth/'+(register?'register':'login'),register?{'email':e,'name':n,'username':u,'password':pw}:{'email':e,'password':pw});
      await widget.onLogin(e,(d['user']['name']??n).toString(),d['token'].toString());
    }catch(e){snack(friendlyError(e,s));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(body:SafeArea(child:Stack(children:[
      Positioned(top:-90,right:-90,child:_Glow(size:250,color:purple.withOpacity(.2))),
      Positioned(bottom:-120,left:-100,child:_Glow(size:280,color:pink.withOpacity(.15))),
      Center(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),child:Column(children:[
        const _BrandMark(),const SizedBox(height:26),
        Text(register?s.createAccount:s.welcomeBack,style:const TextStyle(fontSize:31,fontWeight:FontWeight.w900,letterSpacing:-.8)),
        const SizedBox(height:7),Text(register?s.joinVibe:s.signInContinue,style:const TextStyle(color:muted)),
        const SizedBox(height:22),
        _GlassCard(child:Column(children:[
          if(register)...[
            TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:InputDecoration(prefixIcon:const Icon(Icons.person_outline_rounded),hintText:s.nameHint)),const SizedBox(height:11),
            TextField(controller:username,decoration:InputDecoration(prefixIcon:const Icon(Icons.alternate_email_rounded),hintText:s.usernameHint)),const SizedBox(height:11),
          ],
          TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:InputDecoration(prefixIcon:const Icon(Icons.mail_outline_rounded),hintText:s.email)),const SizedBox(height:11),
          TextField(controller:pass,obscureText:!show1,decoration:InputDecoration(prefixIcon:const Icon(Icons.lock_outline_rounded),hintText:s.password,suffixIcon:IconButton(onPressed:()=>setState(()=>show1=!show1),icon:Icon(show1?Icons.visibility_off_outlined:Icons.visibility_outlined)))),
          if(register)...[
            const SizedBox(height:11),
            TextField(controller:pass2,obscureText:!show2,decoration:InputDecoration(prefixIcon:const Icon(Icons.lock_reset_outlined),hintText:s.repeatPassword,suffixIcon:IconButton(onPressed:()=>setState(()=>show2=!show2),icon:Icon(show2?Icons.visibility_off_outlined:Icons.visibility_outlined)))),
          ],
          const SizedBox(height:16),
          FilledButton(onPressed:busy?null:submit,child:Text(busy?s.wait:(register?s.createAccount:s.signIn),style:const TextStyle(fontWeight:FontWeight.w800))),
        ])),
        const SizedBox(height:10),
        TextButton(onPressed:busy?null:()=>setState(()=>register=!register),child:Text(register?s.alreadyHave:s.newToVibe,style:const TextStyle(fontWeight:FontWeight.w700))),
      ])))),
    ])));
  }
}

String friendlyError(Object ex,AppStrings s){
  final x=ex.toString().replaceFirst('Exception: ','');
  if(x.contains('email_exists'))return s.emailExists;
  if(x.contains('username_taken'))return s.usernameTaken;
  if(x.contains('invalid_username'))return s.invalidUsername;
  if(x.contains('invalid_credentials'))return s.invalidCredentials;
  if(x.contains('timeout')||x.contains('SocketException'))return s.connectionError;
  if(x.contains('http_'))return s.connectionError+' · '+x;
  return s.invalidCredentials;
}

class Chat{final String id;String name,preview,time;bool online;int unread;Chat(this.id,this.name,this.preview,this.time,{this.online=false,this.unread=0});}
class UserX{final String id,name,username;UserX(this.id,this.name,this.username);}
class Msg{final String id,text,sender;final bool mine;Msg(this.id,this.text,this.sender,this.mine);}

class Shell extends StatefulWidget{
  final String name,username,language;final bool light,notifications;
  final ValueChanged<bool> onTheme,onNotifications;final ValueChanged<String> onLanguage;
  final Future<void> Function(String,String) onProfile;final VoidCallback onLogout;
  const Shell({super.key,required this.name,required this.username,required this.light,required this.language,required this.notifications,required this.onTheme,required this.onLanguage,required this.onNotifications,required this.onProfile,required this.onLogout});
  @override State<Shell> createState()=>_ShellState();
}
class _ShellState extends State<Shell>{
  int tab=0;
  void openChat(Chat x)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatPage(chat:x)));
  Future<void> openPerson(UserX u)async{
    try{
      final d=await Api.post('/chats/direct',{'userId':u.id});
      final chat=Chat((d['id']??'').toString(),u.name,(d['preview']??'').toString(),'');
      if(mounted)openChat(chat);
    }catch(e){
      if(!mounted)return;
      final msg=e.toString().contains('cannot_chat_self')?(S(context).ru?'Нельзя открыть чат с собой.':'You cannot chat with yourself.'):S(context).openChatError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));
    }
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(
      body:SafeArea(child:IndexedStack(index:tab,children:[
        Chats(onOpen:openChat,onNewChat:()=>setState(()=>tab=1)),
        Contacts(onOpen:openPerson),
        const Calls(),
        Settings(name:widget.name,username:widget.username,light:widget.light,language:widget.language,notifications:widget.notifications,onTheme:widget.onTheme,onLanguage:widget.onLanguage,onNotifications:widget.onNotifications,onProfile:widget.onProfile,onLogout:widget.onLogout),
      ])),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:[
        NavigationDestination(icon:const Icon(Icons.chat_bubble_outline_rounded),selectedIcon:const Icon(Icons.chat_bubble_rounded),label:s.chats),
        NavigationDestination(icon:const Icon(Icons.people_outline_rounded),selectedIcon:const Icon(Icons.people_alt_rounded),label:s.people),
        NavigationDestination(icon:const Icon(Icons.call_outlined),selectedIcon:const Icon(Icons.call_rounded),label:s.calls),
        NavigationDestination(icon:const Icon(Icons.tune_rounded),selectedIcon:const Icon(Icons.tune_rounded),label:s.settings),
      ]),
    );
  }
}

class Chats extends StatefulWidget{
  final ValueChanged<Chat> onOpen;final VoidCallback onNewChat;
  const Chats({super.key,required this.onOpen,required this.onNewChat});
  @override State<Chats> createState()=>_ChatsState();
}
class _ChatsState extends State<Chats>{
  String q='';bool loading=true;List<Chat> list=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    try{
      final a=await Api.get('/chats');
      list=(a as List).map((x)=>Chat((x['id']??'').toString(),(x['title']??'Chat').toString(),(x['preview']??'').toString(),_time(x['created_at']))).toList();
    }catch(_){}
    if(mounted)setState(()=>loading=false);
  }
  String _time(dynamic v){
    final d=DateTime.tryParse((v??'').toString())?.toLocal();
    if(d==null)return '';
    return d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    final filtered=list.where((x)=>x.name.toLowerCase().contains(q.toLowerCase())||x.preview.toLowerCase().contains(q.toLowerCase())).toList();
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(18,14,12,8),child:Row(children:[
        const _VibeWordmark(),const Spacer(),
        IconButton(tooltip:s.search,onPressed:()async{final x=await showSearch<Chat?>(context:context,delegate:ChatSearch(list));if(x!=null)onOpen(x);},icon:const Icon(Icons.search_rounded)),
        IconButton(tooltip:s.newChat,onPressed:widget.onNewChat,icon:const Icon(Icons.add_comment_rounded)),
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(onChanged:(v)=>setState(()=>q=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),hintText:s.searchChats))),
      const SizedBox(height:10),
      Expanded(child:RefreshIndicator(
        onRefresh:load,
        child:loading?ListView(children:[const SizedBox(height:190),const Center(child:CircularProgressIndicator())]):filtered.isEmpty
          ?ListView(physics:const AlwaysScrollableScrollPhysics(),children:[const SizedBox(height:145),EmptyState(icon:Icons.forum_outlined,title:s.noChats,sub:s.noChatsSub)])
          :ListView.separated(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(12,2,12,24),itemCount:filtered.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(_,i)=>Tile(chat:filtered[i],tap:()=>widget.onOpen(filtered[i]))),
      )),
    ]);
  }
}

class ChatSearch extends SearchDelegate<Chat?>{
  final List<Chat> list;ChatSearch(this.list);
  @override List<Widget>? buildActions(BuildContext c)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear_rounded))];
  @override Widget buildLeading(BuildContext c)=>IconButton(onPressed:()=>close(c,null),icon:const Icon(Icons.arrow_back_rounded));
  @override Widget buildResults(BuildContext c)=>result(c);
  @override Widget buildSuggestions(BuildContext c)=>result(c);
  Widget result(BuildContext c){
    final q=query.toLowerCase();
    return ListView(padding:const EdgeInsets.all(12),children:list.where((x)=>x.name.toLowerCase().contains(q)).map((x)=>Tile(chat:x,tap:()=>close(c,x))).toList());
  }
}

class Tile extends StatelessWidget{
  final Chat chat;final VoidCallback tap;
  const Tile({super.key,required this.chat,required this.tap});
  @override Widget build(BuildContext context)=>Card(child:InkWell(
    onTap:tap,borderRadius:BorderRadius.circular(22),
    child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
      Avatar(name:chat.name,size:56),const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(chat.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
        const SizedBox(height:4),
        Text(chat.preview.isEmpty?S(context).active:chat.preview,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:13)),
      ])),
      if(chat.time.isNotEmpty)Text(chat.time,style:const TextStyle(color:muted,fontSize:11)),
    ])),
  ));
}

class Avatar extends StatelessWidget{
  final String name;final double size;
  const Avatar({super.key,required this.name,this.size=46});
  @override Widget build(BuildContext context){
    const colors=[purple,pink,blue,green];final i=name.isEmpty?0:name.codeUnitAt(0)%colors.length;
    return Container(width:size,height:size,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[colors[i],colors[(i+1)%colors.length]]),boxShadow:[BoxShadow(color:colors[i].withOpacity(.2),blurRadius:16)]),child:Text(name.isEmpty?'?':name[0].toUpperCase(),style:TextStyle(color:Colors.white,fontSize:size*.34,fontWeight:FontWeight.w900)));
  }
}

class ChatPage extends StatefulWidget{
  final Chat chat;const ChatPage({super.key,required this.chat});@override State<ChatPage> createState()=>_ChatState();
}
class _ChatState extends State<ChatPage>{
  final input=TextEditingController();final scroll=ScrollController();List<Msg> msgs=[];
  bool loading=true,sending=false;IO.Socket? socket;String myId='';
  @override void initState(){super.initState();load();}
  @override void dispose(){socket?.disconnect();socket?.dispose();input.dispose();scroll.dispose();super.dispose();}
  Future<void> load()async{
    try{
      final me=await Api.get('/me');myId=(me['id']??'').toString();
      final a=await Api.get('/chats/'+widget.chat.id+'/messages');
      msgs=(a as List).map((x)=>Msg((x['id']??'').toString(),(x['body']??'').toString(),(x['sender_name']??'').toString(),(x['sender_id']??'').toString()==myId)).toList();
      await connectRealtime();
    }catch(_){}
    if(mounted){setState(()=>loading=false);WidgetsBinding.instance.addPostFrameCallback((_)=>scrollEnd());}
  }
  Future<void> connectRealtime()async{
    final t=await Api.token();if(t==null)return;
    socket=IO.io(apiBase,IO.OptionBuilder().setTransports(['websocket']).setAuth({'token':t}).disableAutoConnect().build());
    socket!.onConnect((_)=>socket!.emit('joinChat',widget.chat.id));
    socket!.on('message',(data){
      if(!mounted||data is! Map)return;
      final id=(data['id']??'').toString();if(id.isEmpty||msgs.any((m)=>m.id==id))return;
      setState(()=>msgs.add(Msg(id,(data['body']??'').toString(),(data['sender_name']??'').toString(),(data['sender_id']??'').toString()==myId)));
      WidgetsBinding.instance.addPostFrameCallback((_)=>scrollEnd());
    });
    socket!.connect();
  }
  Future<void> send()async{
    final body=input.text.trim();if(body.isEmpty||sending)return;
    setState(()=>sending=true);
    try{
      if(socket?.connected==true)socket!.emit('message',{'chatId':widget.chat.id,'body':body,'type':'text'});
      else{
        final x=await Api.post('/chats/'+widget.chat.id+'/messages',{'body':body,'type':'text'});
        final id=(x['id']??DateTime.now().microsecondsSinceEpoch).toString();
        if(mounted&&!msgs.any((m)=>m.id==id))setState(()=>msgs.add(Msg(id,body,'',true)));
      }
      input.clear();WidgetsBinding.instance.addPostFrameCallback((_)=>scrollEnd());
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).messageNotSent)));}
    finally{if(mounted)setState(()=>sending=false);}
  }
  void scrollEnd(){if(!scroll.hasClients)return;scroll.animateTo(scroll.position.maxScrollExtent,duration:const Duration(milliseconds:220),curve:Curves.easeOut);}
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(
      appBar:AppBar(titleSpacing:0,title:InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>showContact(context),child:Padding(padding:const EdgeInsets.symmetric(horizontal:5,vertical:5),child:Row(children:[
        Avatar(name:widget.chat.name,size:40),const SizedBox(width:9),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.chat.name,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),Text(widget.chat.online?s.online:s.active,style:const TextStyle(color:muted,fontSize:11))]),
      ]))),actions:[
        IconButton(tooltip:s.voiceCall,onPressed:()=>openCall(context,false),icon:const Icon(Icons.call_outlined)),
        IconButton(tooltip:s.profile,onPressed:()=>showChatMenu(context),icon:const Icon(Icons.more_horiz_rounded)),
      ]),
      body:Column(children:[
        Expanded(child:DecoratedBox(
          decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[purple.withOpacity(.035),Colors.transparent,pink.withOpacity(.03)])),
          child:loading?const Center(child:CircularProgressIndicator()):msgs.isEmpty?EmptyState(icon:Icons.auto_awesome_outlined,title:s.joinVibe,sub:s.noChatsSub):ListView.builder(controller:scroll,padding:const EdgeInsets.fromLTRB(14,18,14,14),itemCount:msgs.length,itemBuilder:(_,i)=>Bubble(msg:msgs[i])),
        )),
        SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(10,6,10,10),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
          _CircleAction(icon:Icons.add_rounded,onTap:()=>showAttachments(context)),const SizedBox(width:8),
          Expanded(child:TextField(controller:input,maxLines:5,decoration:InputDecoration(hintText:s.messageHint,contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:13)))),
          const SizedBox(width:8),_CircleAction(icon:Icons.arrow_upward_rounded,filled:true,busy:sending,onTap:send),
        ]))),
      ]),
    );
  }
  void showContact(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,24),child:Column(mainAxisSize:MainAxisSize.min,children:[
      Avatar(name:widget.chat.name,size:84),const SizedBox(height:12),Text(widget.chat.name,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:15),
      ListTile(leading:const Icon(Icons.call_outlined),title:Text(s.voiceCall),onTap:(){Navigator.pop(context);openCall(context,false);}),
      ListTile(leading:const Icon(Icons.videocam_outlined),title:Text(s.videoCall),onTap:(){Navigator.pop(context);openCall(context,true);}),
    ]))));
  }
  void showChatMenu(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.person_outline_rounded),title:Text(s.profile),onTap:(){Navigator.pop(context);showContact(context);}),
      ListTile(leading:const Icon(Icons.refresh_rounded),title:Text(s.refresh),onTap:(){Navigator.pop(context);setState(()=>loading=true);load();}),
      const SizedBox(height:10),
    ])));
  }
  void showAttachments(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.photo_library_outlined),title:Text(s.ru?'Фото / видео':'Photo / video'),onTap:(){Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.mediaNext)));}),
      ListTile(leading:const Icon(Icons.mic_none_rounded),title:Text(s.ru?'Голосовое сообщение':'Voice message'),onTap:(){Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.mediaNext)));}),
      const SizedBox(height:10),
    ])));
  }
  void openCall(BuildContext context,bool video)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CallPage(name:widget.chat.name,video:video)));
}

class Bubble extends StatelessWidget{
  final Msg msg;const Bubble({super.key,required this.msg});
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Align(alignment:msg.mine?Alignment.centerRight:Alignment.centerLeft,child:Container(
      constraints:const BoxConstraints(maxWidth:325),margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:15,vertical:11),
      decoration:BoxDecoration(gradient:msg.mine?const LinearGradient(colors:[purple,pink]):null,color:msg.mine?null:(dark?surface2:Colors.white),borderRadius:BorderRadius.only(topLeft:const Radius.circular(18),topRight:const Radius.circular(18),bottomLeft:Radius.circular(msg.mine?18:5),bottomRight:Radius.circular(msg.mine?5:18)),border:msg.mine?null:Border.all(color:dark?stroke:Colors.black12)),
      child:Text(msg.text,style:TextStyle(color:msg.mine?Colors.white:null,fontSize:15,height:1.3)),
    ));
  }
}

class Contacts extends StatefulWidget{
  final ValueChanged<UserX> onOpen;const Contacts({super.key,required this.onOpen});@override State<Contacts> createState()=>_ContactsState();
}
class _ContactsState extends State<Contacts>{
  String q='';bool loading=true;List<UserX> people=[];
  @override void initState(){super.initState();search();}
  Future<void> search()async{
    if(!mounted)return;setState(()=>loading=true);
    try{
      final a=await Api.get('/users?q='+Uri.encodeQueryComponent(q));
      people=(a as List).map((x)=>UserX((x['id']??'').toString(),(x['display_name']??'User').toString(),(x['username']??'').toString())).toList();
    }catch(_){people=[];}
    if(mounted)setState(()=>loading=false);
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,18,20,12),child:Row(children:[Text(s.people,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900,letterSpacing:-.7)),const Spacer(),IconButton(tooltip:s.refresh,onPressed:search,icon:const Icon(Icons.refresh_rounded))])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(onChanged:(v){q=v.trim();search();},decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),hintText:s.findPeopleHint))),
      const SizedBox(height:10),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):people.isEmpty?ListView(children:[const SizedBox(height:140),EmptyState(icon:Icons.person_search_outlined,title:s.noPeople,sub:s.noPeopleSub)]):ListView.separated(
        padding:const EdgeInsets.fromLTRB(12,3,12,24),itemCount:people.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
        itemBuilder:(_,i){final u=people[i];return Card(child:InkWell(borderRadius:BorderRadius.circular(22),onTap:()=>widget.onOpen(u),child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
          Avatar(name:u.name,size:52),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(u.name,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:3),Text('@'+u.username,style:const TextStyle(color:muted))])),const Icon(Icons.arrow_forward_ios_rounded,size:15),
        ]))));},
      )),
    ]);
  }
}

class Calls extends StatelessWidget{
  const Calls({super.key});
  @override Widget build(BuildContext context){
    final s=S(context);
    return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(20,18,20,12),child:Align(alignment:Alignment.centerLeft,child:Text(s.calls,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900)))),Expanded(child:EmptyState(icon:Icons.call_rounded,title:s.callsNext,sub:s.callsSub))]);
  }
}

class Settings extends StatelessWidget{
  final String name,username,language;final bool light,notifications;
  final ValueChanged<bool> onTheme,onNotifications;final ValueChanged<String> onLanguage;
  final Future<void> Function(String,String) onProfile;final VoidCallback onLogout;
  const Settings({super.key,required this.name,required this.username,required this.light,required this.language,required this.notifications,required this.onTheme,required this.onLanguage,required this.onNotifications,required this.onProfile,required this.onLogout});
  @override Widget build(BuildContext context){
    final s=S(context);
    return ListView(padding:const EdgeInsets.fromLTRB(18,16,18,30),children:[
      const _VibeWordmark(),const SizedBox(height:18),
      Card(child:InkWell(borderRadius:BorderRadius.circular(22),onTap:()=>edit(context),child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[
        Avatar(name:name,size:62),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('@'+username,style:const TextStyle(color:muted))])),const Icon(Icons.arrow_forward_ios_rounded,size:16),
      ])))),
      const SizedBox(height:12),
      Card(child:SwitchListTile(value:!light,onChanged:(v)=>onTheme(!v),secondary:const Icon(Icons.nights_stay_outlined),title:Text(s.darkY2K,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(s.darkY2KSub,style:const TextStyle(color:muted)))),
      const SizedBox(height:12),
      Card(child:SwitchListTile(value:notifications,onChanged:onNotifications,secondary:const Icon(Icons.notifications_none_rounded),title:Text(s.notifications,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(notifications?s.notificationsOn:s.notificationsOff,style:const TextStyle(color:muted)))),
      section(context,s.language,[ListTile(leading:const Icon(Icons.translate_rounded),title:Text(s.language),subtitle:Text(language=='ru'?s.russian:s.english,style:const TextStyle(color:muted)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>languagePicker(context))]),
      section(context,s.security,[
        ListTile(leading:const Icon(Icons.lock_outline_rounded),title:Text(s.privacy),subtitle:Text(s.privacySub,style:const TextStyle(color:muted,fontSize:12)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>info(context,s.privacy,s.privacyBody)),
        ListTile(leading:const Icon(Icons.shield_outlined),title:Text(s.security),subtitle:Text(s.securitySub,style:const TextStyle(color:muted,fontSize:12)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>info(context,s.security,s.securityBody)),
      ]),
      section(context,s.about,[ListTile(leading:const Icon(Icons.info_outline_rounded),title:Text(s.about),subtitle:Text(s.version,style:const TextStyle(color:muted)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>info(context,'vibe<3',s.aboutBody))]),
      const SizedBox(height:18),
      OutlinedButton.icon(onPressed:onLogout,icon:const Icon(Icons.logout_rounded),label:Text(s.signOut),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),
    ]);
  }
  Widget section(BuildContext c,String title,List<Widget> children)=>Padding(padding:const EdgeInsets.only(top:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.only(left:4,bottom:7),child:Text(title.toUpperCase(),style:const TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.2))),Card(child:Column(children:children))]));
  void languagePicker(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,8,20,4),child:Text(s.chooseLanguage,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900))),
      ListTile(leading:const Text('🇷🇺',style:TextStyle(fontSize:24)),title:Text(s.russian),trailing:language=='ru'?const Icon(Icons.check_rounded,color:purple):null,onTap:(){Navigator.pop(context);onLanguage('ru');}),
      ListTile(leading:const Text('🇺🇸',style:TextStyle(fontSize:24)),title:Text(s.english),trailing:language=='en'?const Icon(Icons.check_rounded,color:purple):null,onTap:(){Navigator.pop(context);onLanguage('en');}),
      const SizedBox(height:12),
    ])));
  }
  void edit(BuildContext context){
    final s=S(context);final n=TextEditingController(text:name);final u=TextEditingController(text:username);bool busy=false;
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
      title:Text(s.editProfile),
      content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:InputDecoration(labelText:s.name)),const SizedBox(height:11),TextField(controller:u,decoration:InputDecoration(labelText:s.username,prefixText:'@')),const SizedBox(height:7),Align(alignment:Alignment.centerLeft,child:Text(s.usernameRules,style:const TextStyle(color:muted,fontSize:11)))]),
      actions:[
        TextButton(onPressed:busy?null:()=>Navigator.pop(ctx),child:Text(s.cancel)),
        FilledButton(onPressed:busy?null:()async{
          final nn=n.text.trim();final uu=u.text.trim().toLowerCase().replaceFirst('@','');
          if(nn.length<2||!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(uu)){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.profileCheck)));return;}
          setLocal(()=>busy=true);
          try{await onProfile(nn,uu);if(ctx.mounted)Navigator.pop(ctx);}catch(e){setLocal(()=>busy=false);final x=e.toString();ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x.contains('username_taken')?s.usernameTaken:s.profileSaveError))); }
        },child:Text(busy?s.wait:s.save)),
      ],
    )));
  }
  void info(BuildContext context,String title,String body)=>showDialog(context:context,builder:(_)=>AlertDialog(title:Text(title),content:Text(body),actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:Text(S(context).ok))]));
}

class CallPage extends StatelessWidget{
  final String name;final bool video;const CallPage({super.key,required this.name,required this.video});
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(body:Stack(children:[
      Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[bg,purple.withOpacity(.14),pink.withOpacity(.08)])))),
      Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Avatar(name:name,size:112),const SizedBox(height:18),Text(name,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(video?s.videoCall:s.voiceCall,style:const TextStyle(color:muted)),const SizedBox(height:12),Text(s.callConnect,style:const TextStyle(color:muted)),const SizedBox(height:28),FilledButton.icon(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.call_end_rounded),label:Text(s.endCall),style:FilledButton.styleFrom(backgroundColor:Colors.redAccent,minimumSize:const Size(170,52))),
      ])),
    ]));
  }
}

class EmptyState extends StatelessWidget{
  final IconData icon;final String title,sub;const EmptyState({super.key,required this.icon,required this.title,required this.sub});
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:88,height:88,decoration:BoxDecoration(shape:BoxShape.circle,color:purple.withOpacity(.1),border:Border.all(color:purple.withOpacity(.18))),child:Icon(icon,size:42,color:purple)),
    const SizedBox(height:18),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:7),Text(sub,textAlign:TextAlign.center,style:const TextStyle(color:muted,fontSize:13,height:1.45)),
  ])));
}

class _BrandMark extends StatelessWidget{
  const _BrandMark();
  @override Widget build(BuildContext context)=>Container(width:96,height:96,alignment:Alignment.center,decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[purple,pink]),boxShadow:[BoxShadow(color:purple,blurRadius:34,spreadRadius:-10)]),child:const Text('v<3',style:TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.w900,letterSpacing:-1.5)));
}
class _VibeWordmark extends StatelessWidget{
  const _VibeWordmark();
  @override Widget build(BuildContext context)=>const Text('vibe<3',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,letterSpacing:-1.1));
}
class _GlassCard extends StatelessWidget{
  final Widget child;const _GlassCard({required this.child});
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:(dark?surface:Colors.white).withOpacity(.86),borderRadius:BorderRadius.circular(26),border:Border.all(color:dark?stroke:Colors.black12),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.08),blurRadius:28,offset:const Offset(0,12))]),child:child);
  }
}
class _Glow extends StatelessWidget{
  final double size;final Color color;const _Glow({required this.size,required this.color});
  @override Widget build(BuildContext context)=>IgnorePointer(child:Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle,color:color,boxShadow:[BoxShadow(color:color,blurRadius:90,spreadRadius:30)])));
}
class _CircleAction extends StatelessWidget{
  final IconData icon;final VoidCallback onTap;final bool filled,busy;
  const _CircleAction({required this.icon,required this.onTap,this.filled=false,this.busy=false});
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Material(color:filled?purple:(dark?surface2:const Color(0xFFECEAF2)),borderRadius:BorderRadius.circular(18),child:InkWell(borderRadius:BorderRadius.circular(18),onTap:onTap,child:SizedBox(width:50,height:50,child:Center(child:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):Icon(icon,color:filled?Colors.white:null)))));
  }
}