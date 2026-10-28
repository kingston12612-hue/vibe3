import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

String apiBase=const String.fromEnvironment('VIBE_API',defaultValue:'https://vibe3-api.onrender.com');
const bg=Color(0xFF0A0A10),surface=Color(0xFF15151D),surface2=Color(0xFF1C1C26),stroke=Color(0xFF282833),green=Color(0xFF59E391);
const muted=Color(0xFF9193A5),purple=Color(0xFF9B6BFF),blue=Color(0xFF6FA8FF),pink=Color(0xFFE76BD0);
const brandGrad=[pink,purple];

Future<void> main()async{
  WidgetsFlutterBinding.ensureInitialized();
  try{
    final p=await SharedPreferences.getInstance();
    final u=p.getString('server_url');
    if(u!=null&&u.trim().length>8)apiBase=u.trim().replaceAll(RegExp(r'/+$'),'');
  }catch(_){}
  runApp(const VibeApp());
}

class Api{
 static bool _awake=false;
 static Future<String?> token()async=>(await SharedPreferences.getInstance()).getString('token');
 static Future<Map<String,String>> headers()async{final t=await token();return {'Content-Type':'application/json',if(t!=null)'Authorization':'Bearer $t'};}
 static bool _transient(Object e)=>e is TimeoutException||e is SocketException||e is HandshakeException||e is http.ClientException||['timeout','socketexception','clientexception','handshake','oserror','connection refused','connection reset','network is unreachable','failed host lookup'].any((k)=>e.toString().toLowerCase().contains(k));
 // Render free просыпается 30-60 сек: пингуем /health, пока не ответит
 static Future<void> _ensureAwake()async{
  for(int i=0;i<8;i++){
   try{final r=await http.get(Uri.parse('$apiBase/health')).timeout(const Duration(seconds:8));if(r.statusCode==200)return;}catch(_){}
   try{await Future.delayed(const Duration(milliseconds:2000));}catch(_){}
  }
 }
 static Future<T> _guard<T>(Future<T> Function() fn)async{
  try{return await fn();}catch(e){
   if(_awake||!_transient(e))rethrow;
   _awake=true;
   await _ensureAwake();
   return await fn();
  }
 }
 static Future<dynamic> get(String path)=>_guard(()async{final r=await http.get(Uri.parse('$apiBase$path'),headers:await headers()).timeout(const Duration(seconds:60));if(r.statusCode<200||r.statusCode>=300)throw Exception('http_${r.statusCode}');return jsonDecode(r.body);});
 static Future<dynamic> post(String path,Map<String,dynamic> body)=>_guard(()async{final r=await http.post(Uri.parse('$apiBase$path'),headers:await headers(),body:jsonEncode(body)).timeout(const Duration(seconds:60));dynamic d;try{d=jsonDecode(r.body);}catch(_){d={};}if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map&&d['error']!=null?'${d['error']}:http_${r.statusCode}':'http_${r.statusCode}');return d;});
 static Future<dynamic> put(String path,Map<String,dynamic> body)=>_guard(()async{final r=await http.put(Uri.parse('$apiBase$path'),headers:await headers(),body:jsonEncode(body)).timeout(const Duration(seconds:60));dynamic d;try{d=jsonDecode(r.body);}catch(_){d={};}if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map&&d['error']!=null?'${d['error']}:http_${r.statusCode}':'http_${r.statusCode}');return d;});
}

class AppStrings {
  final bool ru;
  const AppStrings(this.ru);
  String get chats=>ru?'Чаты':'Chats';
  String get people=>ru?'Контакты':'Contacts';
  String get calls=>ru?'Звонки':'Calls';
  String get settings=>ru?'Настройки':'Settings';
  String get search=>ru?'поиск':'search';
  String get searchChats=>ru?'поиск по чатам':'search chats';
  String get newChat=>ru?'Новый чат':'New chat';
  String get noChats=>ru?'Пока нет чатов':'No chats yet';
  String get noChatsSub=>ru?'Найди человека и начни разговор.':'Find someone and start a conversation.';
  String get noPeople=>ru?'Ничего не найдено':'No people found';
  String get noPeopleSub=>ru?'Попробуй имя или @username.':'Try a name or @username.';
  String get findPeopleHint=>ru?'имя или @username':'name or @username';
  String get messageHint=>ru?'сообщение...':'message...';
  String get online=>ru?'в сети':'online';
  String get active=>ru?'на vibe<3':'on vibe<3';
  String get typingNow=>ru?'печатает...':'typing...';
  String get filterAll=>ru?'все':'all';
  String get filterUnread=>ru?'непрочитанные':'unread';
  String get filterDirect=>ru?'личные':'direct';
  String get filterGroups=>ru?'группы':'groups';
  String get effects=>ru?'Эффекты':'Effects';
  String get intensity=>ru?'интенсивность':'intensity';
  String get profile=>ru?'Профиль':'Profile';
  String get editProfile=>ru?'Редактировать профиль':'Edit profile';
  String get name=>ru?'Имя':'Name';
  String get username=>'Username';
  String get save=>ru?'Сохранить':'Save';
  String get cancel=>ru?'Отмена':'Cancel';
  String get ok=>ru?'Готово':'Done';
  String get darkY2K=>ru?'Тёмная тема':'Dark theme';
  String get darkY2KSub=>ru?'Тёмный интерфейс vibe<3':'Vibe<3 dark interface';
  String get language=>ru?'Язык':'Language';
  String get russian=>'Русский';
  String get english=>'English';
  String get privacy=>ru?'Приватность':'Privacy';
  String get privacySub=>ru?'Статусы и прочитанные сообщения':'Presence and read status';
  String get privacyBody=>ru?'Статусы «в сети» и «печатает...» работают в реальном времени, прочитанные сообщения отмечаются автоматически.':'Presence and typing indicators work in real time, read status is marked automatically.';
  String get security=>ru?'Безопасность':'Security';
  String get securitySub=>ru?'Авторизация и защита аккаунта':'Account authentication';
  String get securityBody=>ru?'Вход защищён серверной JWT-сессией, профиль хранится на сервере.':'Login is protected by a server-side JWT session and profile data is stored on the server.';
  String get aboutBody=>ru?'vibe<3 — тёмный Y2K-мессенджер. Аккаунты, личные чаты, эффекты и статусы подключены к серверу.':'vibe<3 — a dark Y2K messenger. Accounts, direct chats, effects and presence are connected to the server.';
  String get notifications=>ru?'Уведомления':'Notifications';
  String get notificationsOn=>ru?'Включены':'Enabled';
  String get notificationsOff=>ru?'Выключены':'Disabled';
  String get about=>ru?'О приложении':'About';
  String get version=>'v1.0.6';
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
  String get callConnect=>ru?'подключаем соединение':'connecting the call';
  String get endCall=>ru?'Завершить':'End call';
  String get refresh=>ru?'Обновить':'Refresh';
  String get chooseLanguage=>ru?'Выбери язык':'Choose language';
  String get emailInvalid=>ru?'Проверь email':'Check your email';
  String get passwordShort=>ru?'Пароль от 6 символов':'Password: 6+ characters';
  String get nameRequired=>ru?'Введи имя':'Enter your name';
  String get usernameRules=>ru?'3-30 символов: a-z, 0-9, _':'3-30 chars: a-z, 0-9, _';
  String get passwordsMismatch=>ru?'Пароли не совпадают':'Passwords do not match';
  String get emailExists=>ru?'Такой email уже занят':'Email already registered';
  String get usernameTaken=>ru?'Этот username уже занят':'Username already taken';
  String get invalidUsername=>ru?'Некорректный username':'Invalid username';
  String get invalidCredentials=>ru?'Неверный email или пароль':'Invalid email or password';
  String get connectionError=>ru?'Нет соединения. Попробуй ещё раз':'Connection error. Try again';
  String get openChatError=>ru?'Не удалось открыть чат':'Could not open the chat';
  String get profileCheck=>ru?'Проверь имя и username':'Check name and username';
  String get profileSaveError=>ru?'Не удалось сохранить':'Could not save';
  String get photoVideo=>ru?'Фото или видео':'Photo or video';
  String get voiceMessage=>ru?'Голосовое сообщение':'Voice message';
  String get messageNotSent=>ru?'Сообщение не отправлено':'Message not sent';
  String get recording=>ru?'Идёт запись...':'Recording...';
  String get stopAndSend=>ru?'Остановить и отправить':'Stop and send';
  String get cancelRecording=>ru?'Отменить запись':'Cancel recording';
  String get mediaTooLarge=>ru?'Файл слишком большой (максимум 7 МБ).':'File is too large (7 MB maximum).';
  String get mediaFailed=>ru?'Не удалось отправить медиа':'Could not send media';
}

AppStrings S(BuildContext c)=>AppStrings(Localizations.localeOf(c).languageCode=='ru');

ThemeData vibeTheme(bool dark){
  const lightBg=Color(0xFFF3F1FA),lightSurface=Color(0xFFFFFFFF),lightSurface2=Color(0xFFEDEAF6);
  const lightStroke=Color(0xFFD9D4E8),lightText=Color(0xFF171522),lightMuted=Color(0xFF686477);
  final pageBg=dark?bg:lightBg;
  final cs=dark
    ? const ColorScheme.dark(primary:purple,onPrimary:Colors.white,secondary:blue,onSecondary:Colors.white,tertiary:pink,onTertiary:Colors.white,surface:surface,onSurface:Color(0xFFF4F4FF),surfaceContainerHighest:surface2,onSurfaceVariant:muted,outline:stroke)
    : const ColorScheme.light(primary:purple,onPrimary:Colors.white,secondary:blue,onSecondary:Colors.white,tertiary:pink,onTertiary:Colors.white,surface:lightSurface,onSurface:lightText,surfaceContainerHighest:lightSurface2,onSurfaceVariant:lightMuted,outline:lightStroke);
  final panel=dark?surface:lightSurface,panel2=dark?surface2:lightSurface2,line=dark?stroke:lightStroke;
  return ThemeData(
    useMaterial3:true,brightness:dark?Brightness.dark:Brightness.light,colorScheme:cs,
    scaffoldBackgroundColor:pageBg,canvasColor:pageBg,
    cardTheme:CardTheme(color:panel,elevation:0,margin:EdgeInsets.zero,surfaceTintColor:Colors.transparent,shadowColor:Colors.transparent,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:BorderSide(color:line))),
    appBarTheme:AppBarTheme(backgroundColor:pageBg,foregroundColor:cs.onSurface,elevation:0,scrolledUnderElevation:0,surfaceTintColor:Colors.transparent),
    bottomSheetTheme:BottomSheetThemeData(backgroundColor:panel,surfaceTintColor:Colors.transparent,modalBackgroundColor:panel,elevation:0,showDragHandle:true),
    dialogTheme:DialogTheme(backgroundColor:panel,surfaceTintColor:Colors.transparent,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24))),
    popupMenuTheme:PopupMenuThemeData(color:panel,surfaceTintColor:Colors.transparent,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20))),
    navigationBarTheme:NavigationBarThemeData(backgroundColor:dark?const Color(0xFF0D0D13):lightSurface,indicatorColor:purple.withOpacity(.16),height:72,labelTextStyle:const WidgetStatePropertyAll(TextStyle(fontSize:11,fontWeight:FontWeight.w800))),
    switchTheme:SwitchThemeData(thumbColor:WidgetStateProperty.resolveWith((s)=>s.contains(WidgetState.selected)?Colors.white:cs.onSurfaceVariant),trackColor:WidgetStateProperty.resolveWith((s)=>s.contains(WidgetState.selected)?pink.withOpacity(.65):line),trackOutlineColor:const WidgetStatePropertyAll(Colors.transparent)),
    sliderTheme:const SliderThemeData(activeTrackColor:pink,inactiveTrackColor:Color(0xFF282833),thumbColor:pink,overlayColor:Color(0x22E76BD0)),
    progressIndicatorTheme:const ProgressIndicatorThemeData(color:pink,linearTrackColor:Color(0xFF282833)),
    listTileTheme:ListTileThemeData(tileColor:Colors.transparent,selectedTileColor:purple.withOpacity(.10)),
    inputDecorationTheme:InputDecorationTheme(filled:false,fillColor:Colors.transparent,hoverColor:Colors.transparent,hintStyle:TextStyle(color:dark?muted:lightMuted),border:InputBorder.none,enabledBorder:InputBorder.none,focusedBorder:InputBorder.none,disabledBorder:InputBorder.none,errorBorder:InputBorder.none,focusedErrorBorder:InputBorder.none,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14)),
    filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),minimumSize:const Size.fromHeight(52))),
    outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(foregroundColor:cs.onSurface,side:BorderSide(color:line),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),minimumSize:const Size.fromHeight(52))),
    snackBarTheme:SnackBarThemeData(behavior:SnackBarBehavior.floating,backgroundColor:panel2,contentTextStyle:TextStyle(color:cs.onSurface),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
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
    if(!ready)return MaterialApp(debugShowCheckedModeBanner:false,theme:vibeTheme(true),home:const VibeSplash());
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
  @override void initState(){
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:Colors.transparent,
      statusBarIconBrightness:Brightness.light,
      systemNavigationBarColor:bg,
      systemNavigationBarIconBrightness:Brightness.light,
      systemNavigationBarDividerColor:bg,
      systemNavigationBarContrastEnforced:false,
    ));
  }
  @override void dispose(){email.dispose();name.dispose();username.dispose();pass.dispose();pass2.dispose();super.dispose();}
  Future<void> _editServer()async{
    final c=TextEditingController(text:apiBase);
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:surface,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
      title:const Text('Адрес сервера',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Обычно менять не нужно. Формат: https://...',style:TextStyle(color:muted,fontSize:12.5)),
        const SizedBox(height:12),
        TextField(controller:c,autofocus:true,keyboardType:TextInputType.url,style:const TextStyle(fontSize:14),decoration:InputDecoration(hintText:'https://vibe3-api.onrender.com',filled:true,fillColor:bg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:stroke)),isDense:true)),
      ]),
      actions:[
        TextButton(onPressed:()=>{c.text='https://vibe3-api.onrender.com'},child:const Text('Стандартный')),
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Отмена')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Сохранить')),
      ],
    ));
    if(ok!=true)return;
    var u=c.text.trim();
    if(u.isEmpty)return;
    if(!u.startsWith('http://')&&!u.startsWith('https://'))u='https://$u';
    u=u.replaceAll(RegExp(r'/+$'),'');
    apiBase=u;
    final p=await SharedPreferences.getInstance();
    await p.setString('server_url',u);
    if(mounted)setState((){});
    await _checkConn();
  }
  void snack(String x)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));
  Future<void> _checkConn()async{
    final s=S(context);
    if(busy)return;
    setState(()=>busy=true);
    final sw=Stopwatch()..start();
    bool ok=false;String detail;
    try{
      final r=await http.get(Uri.parse('$apiBase/health')).timeout(const Duration(seconds:25));
      sw.stop();
      if(r.statusCode==200){ok=true;detail='Сервер отвечает за ${(sw.elapsedMilliseconds/1000).toStringAsFixed(1)} с.\n\nСвязь есть — если вход всё равно не проходит, проблема в данных аккаунта, а не в сети.';}
      else{sw.stop();detail='Сервер ответил ошибкой HTTP ${r.statusCode}. Сними скриншот и отправь разработчику.';}
    }catch(e){
      sw.stop();
      final x=e.toString();
      if(x.contains('Failed host lookup'))detail='Телефон вообще не находит этот адрес.\n\nПроверь адрес кнопкой выше и смени сеть: Wi-Fi ↔ мобильный интернет.';
      else if(x.contains('TimeoutException')||x.contains('timeout'))detail='Сервер не отвечает уже ${(sw.elapsedMilliseconds/1000).toStringAsFixed(0)} с — либо просыпается, либо сеть его блокирует. Подожди полминуты и проверь ещё раз; если в браузере телефона сайт открывается, а тут нет — смени сеть.';
      else if(x.contains('HandshakeException'))detail='Ошибка шифрования (TLS) между телефоном и сервером. Смени сеть (Wi-Fi ↔ мобильный интернет) — часто помогает.';
      else detail='Не удалось подключиться:\n\n$x\n\nСмени сеть (Wi-Fi ↔ мобильный интернет) и проверь адрес сервера.';
    }
    if(!mounted)return;
    setState(()=>busy=false);
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:surface,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
      title:Row(children:[Icon(ok?Icons.wifi_rounded:Icons.wifi_off_rounded,size:20,color:ok?green:pink),const SizedBox(width:8),Text(ok?'Связь есть':'Связи нет',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17))]),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Сервер: $apiBase',style:const TextStyle(color:muted,fontSize:11.5)),
        const SizedBox(height:12),
        Text(detail,style:const TextStyle(fontSize:13.5,height:1.45)),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Понятно'))],
    ));
  }
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
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Scaffold(
      backgroundColor:bg,
      extendBody:true,
      body:SafeArea(
        child:Container(
          color:bg,
          child:Stack(
            children:[
              Positioned(top:-120,right:-90,child:_Glow(size:300,color:purple.withOpacity(.20))),
              Positioned(bottom:-140,left:-110,child:_Glow(size:320,color:pink.withOpacity(.16))),
              Positioned(top:170,left:-150,child:_Glow(size:230,color:blue.withOpacity(.06))),
              SingleChildScrollView(
                padding:const EdgeInsets.fromLTRB(24,22,24,30),
                child:Center(
                  child:ConstrainedBox(
                    constraints:const BoxConstraints(maxWidth:520),
                    child:Column(
                      crossAxisAlignment:CrossAxisAlignment.start,
                      children:[
                        Row(
                          children:[
                            const _BrandMark(),
                            const SizedBox(width:14),
                            const Column(
                              crossAxisAlignment:CrossAxisAlignment.start,
                              children:[
                                _VibeWordmark(fontSize:27),
                                SizedBox(height:2),
                                Text('private. personal. yours.',style:TextStyle(color:muted,fontSize:12,fontWeight:FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height:42),
                        Text(register?s.createAccount:s.welcomeBack,style:const TextStyle(fontSize:36,fontWeight:FontWeight.w900,letterSpacing:-1.2,height:1.05)),
                        const SizedBox(height:9),
                        Text(register?s.joinVibe:s.signInContinue,style:const TextStyle(color:muted,fontSize:14,height:1.45)),
                        const SizedBox(height:26),
                        Row(children:[
                          Expanded(child:_AuthMode(label:s.signIn,active:!register,onTap:busy?null:(){FocusScope.of(context).unfocus();setState(()=>register=false);})),
                          const SizedBox(width:10),
                          Expanded(child:_AuthMode(label:s.createAccount,active:register,onTap:busy?null:(){FocusScope.of(context).unfocus();setState(()=>register=true);})),
                        ]),
                        const SizedBox(height:20),
                        AnimatedSwitcher(
                          duration:const Duration(milliseconds:280),
                          switchInCurve:Curves.easeOutCubic,
                          switchOutCurve:Curves.easeInCubic,
                          transitionBuilder:(child,animation)=>FadeTransition(opacity:animation,child:SlideTransition(position:Tween<Offset>(begin:const Offset(0,.035),end:Offset.zero).animate(animation),child:child)),
                          child:register
                            ?Column(key:const ValueKey('register-fields'),children:[
                                _AuthField(controller:name,icon:Icons.person_outline_rounded,hint:s.nameHint,textCapitalization:TextCapitalization.words),
                                const SizedBox(height:11),
                                _AuthField(controller:username,icon:Icons.alternate_email_rounded,hint:s.usernameHint),
                                const SizedBox(height:11),
                              ])
                            :const SizedBox.shrink(key:ValueKey('login-fields')),
                        ),
                        _AuthField(controller:email,icon:Icons.mail_outline_rounded,hint:s.email,keyboardType:TextInputType.emailAddress),
                        const SizedBox(height:11),
                        _AuthField(
                          controller:pass,
                          icon:Icons.lock_outline_rounded,
                          hint:s.password,
                          obscureText:!show1,
                          suffix:IconButton(onPressed:busy?null:()=>setState(()=>show1=!show1),icon:Icon(show1?Icons.visibility_off_outlined:Icons.visibility_outlined)),
                        ),
                        AnimatedSwitcher(
                          duration:const Duration(milliseconds:260),
                          switchInCurve:Curves.easeOutCubic,
                          switchOutCurve:Curves.easeInCubic,
                          transitionBuilder:(child,animation)=>FadeTransition(opacity:animation,child:SizeTransition(sizeFactor:animation,axisAlignment:-1,child:child)),
                          child:register
                            ?Padding(
                                key:const ValueKey('repeat-password'),
                                padding:const EdgeInsets.only(top:11),
                                child:_AuthField(
                                  controller:pass2,
                                  icon:Icons.lock_reset_outlined,
                                  hint:s.repeatPassword,
                                  obscureText:!show2,
                                  suffix:IconButton(onPressed:busy?null:()=>setState(()=>show2=!show2),icon:Icon(show2?Icons.visibility_off_outlined:Icons.visibility_outlined)),
                                ),
                              )
                            :const SizedBox.shrink(key:ValueKey('no-repeat-password')),
                        ),
                        const SizedBox(height:18),
                        _GradientButton(height:56,radius:17,busy:busy,onTap:submit,icon:register?Icons.arrow_forward_rounded:Icons.login_rounded,label:register?s.createAccount:s.signIn),
                        const SizedBox(height:16),
                        Row(
                          mainAxisAlignment:MainAxisAlignment.center,
                          children:[
                            Icon(Icons.lock_outline_rounded,size:13,color:(dark?muted:Colors.black45)),
                            const SizedBox(width:6),
                            Text(s.securitySub,textAlign:TextAlign.center,style:const TextStyle(color:muted,fontSize:11.5,height:1.3)),
                          ],
                        ),
                        const SizedBox(height:6),
                        Center(child:TextButton.icon(
                          onPressed:busy?null:_editServer,
                          style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),minimumSize:Size.zero),
                          icon:Icon(Icons.dns_outlined,size:14,color:muted.withOpacity(.8)),
                          label:Text(apiBase.replaceAll(RegExp(r'^https?://'),''),style:const TextStyle(color:muted,fontSize:10.5)),
                        )),
                        Center(child:TextButton.icon(
                          onPressed:busy?null:_checkConn,
                          style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),minimumSize:Size.zero),
                          icon:Icon(Icons.wifi_tethering_rounded,size:14,color:muted.withOpacity(.8)),
                          label:const Text('проверить связь',style:TextStyle(color:muted,fontSize:10.5)),
                        )),
                        const SizedBox(height:22),
                        Center(
                          child:TextButton(
                            onPressed:busy?null:(){FocusScope.of(context).unfocus();setState(()=>register=!register);},
                            child:Text(register?s.alreadyHave:s.newToVibe,style:const TextStyle(fontWeight:FontWeight.w800)),
                          ),
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
    );
  }
}

class _AuthMode extends StatelessWidget{
  final String label;final bool active;final VoidCallback? onTap;
  const _AuthMode({required this.label,required this.active,required this.onTap});
  @override Widget build(BuildContext context)=>AnimatedContainer(
    duration:const Duration(milliseconds:220),
    curve:Curves.easeOutCubic,
    height:48,
    decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(15),
      gradient:active?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad):null,
      color:active?null:Colors.transparent,
      border:Border.all(color:Colors.transparent),
      boxShadow:active?[BoxShadow(color:pink.withOpacity(.22),blurRadius:18,offset:const Offset(0,6))]:null,
    ),
    child:Material(
      color:Colors.transparent,
      child:InkWell(
        onTap:onTap,
        borderRadius:BorderRadius.circular(15),
        child:Center(child:Text(label,style:TextStyle(fontWeight:FontWeight.w900,fontSize:13,letterSpacing:.1,color:active?Colors.white:muted))),
      ),
    ),
  );
}

class _AuthField extends StatefulWidget{
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  const _AuthField({required this.controller,required this.icon,required this.hint,this.obscureText=false,this.suffix,this.keyboardType,this.textCapitalization=TextCapitalization.none});
  @override State<_AuthField> createState()=>_AuthFieldState();
}
class _AuthFieldState extends State<_AuthField>{
  late final FocusNode focusNode;
  @override void initState(){super.initState();focusNode=FocusNode();}
  @override void dispose(){focusNode.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Container(
      height:56,
      width:double.infinity,
      decoration:BoxDecoration(
        color:dark?surface.withOpacity(.7):Colors.white,
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:dark?stroke:Colors.black12),
      ),
      padding:const EdgeInsets.only(left:16),
      child:Row(
        children:[
          Icon(widget.icon,color:dark?muted:Colors.black54,size:20),
          const SizedBox(width:8),
          Expanded(
            child:Stack(
              alignment:Alignment.centerLeft,
              children:[
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable:widget.controller,
                  builder:(context,value,_){
                    if(value.text.isNotEmpty)return const SizedBox.shrink();
                    return IgnorePointer(child:Text(widget.hint,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:16)));
                  },
                ),
                EditableText(
                  controller:widget.controller,
                  focusNode:focusNode,
                  obscureText:widget.obscureText,
                  obscuringCharacter:'•',
                  keyboardType:widget.keyboardType??TextInputType.text,
                  textCapitalization:widget.textCapitalization,
                  maxLines:1,
                  minLines:1,
                  style:const TextStyle(fontWeight:FontWeight.w600,fontSize:16),
                  cursorColor:pink,
                  backgroundCursorColor:muted,
                  selectionColor:pink.withOpacity(.25),
                ),
              ],
            ),
          ),
          if(widget.suffix!=null) widget.suffix!,
          const SizedBox(width:6),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget{
  final double height;final double radius;final bool busy;final VoidCallback? onTap;final IconData? icon;final String label;
  const _GradientButton({required this.height,required this.radius,required this.busy,required this.onTap,required this.label,this.icon});
  @override Widget build(BuildContext context){
    return SizedBox(
      width:double.infinity,
      height:height,
      child:DecoratedBox(
        decoration:BoxDecoration(
          gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),
          borderRadius:BorderRadius.circular(radius),
          border:Border.all(color:Colors.white.withOpacity(.10)),
          boxShadow:[BoxShadow(color:pink.withOpacity(.24),blurRadius:22,offset:const Offset(0,9))],
        ),
        child:Material(
          color:Colors.transparent,
          child:InkWell(
            onTap:busy?null:onTap,
            borderRadius:BorderRadius.circular(radius),
            child:Center(
              child:AnimatedSwitcher(
                duration:const Duration(milliseconds:180),
                child:busy
                  ?const SizedBox(key:ValueKey('busy'),width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                  :Row(
                      key:const ValueKey('ready'),
                      mainAxisSize:MainAxisSize.min,
                      children:[
                        if(icon!=null)Icon(icon,size:19,color:Colors.white),
                        if(icon!=null)const SizedBox(width:9),
                        Text(label,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15,color:Colors.white)),
                      ],
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String friendlyError(Object ex,AppStrings s){
  final x=ex.toString().replaceFirst('Exception: ','');
  if(x.contains('email_exists'))return s.emailExists;
  if(x.contains('username_taken'))return s.usernameTaken;
  if(x.contains('invalid_username'))return s.invalidUsername;
  if(x.contains('invalid_credentials'))return s.invalidCredentials;
  if(x.contains('http_429'))return ru429(s);
  if(x.contains('http_5'))return s.connectionError+' · сервер недоступен, попробуй через минуту';
  if(x.contains('TimeoutException')||x.contains('timeout'))return s.connectionError+' · сервер не отвечает';
  if(x.contains('Failed host lookup'))return s.connectionError+' · адрес не найден — проверь сервер внизу экрана';
  if(x.contains('SocketException')||x.contains('ClientException')||x.contains('HandshakeException')||x.contains('Connection')||x.contains('connection'))return s.connectionError;
  if(x.contains('http_'))return s.connectionError+' · '+x;
  return s.connectionError+' · '+x;
}
String ru429(AppStrings s)=>s.connectionError+' · слишком много попыток, подожди минуту';

class Chat{final String id;String name,preview,time;bool online,isGroup;int unread;DateTime? lastAt;Chat(this.id,this.name,this.preview,this.time,{this.online=false,this.unread=0,this.isGroup=false,this.lastAt});}
class UserX{final String id,name,username;UserX(this.id,this.name,this.username);}
class Msg{final String id,text,sender,type,mediaUrl;final bool mine;final DateTime createdAt;Msg(this.id,this.text,this.sender,this.mine,{this.type='text',this.mediaUrl='',DateTime? createdAt}):createdAt=createdAt??DateTime.now();}
class Shell extends StatefulWidget{
  final String name,username,language;final bool light,notifications;
  final ValueChanged<bool> onTheme,onNotifications;final ValueChanged<String> onLanguage;
  final Future<void> Function(String,String) onProfile;final VoidCallback onLogout;
  const Shell({super.key,required this.name,required this.username,required this.light,required this.language,required this.notifications,required this.onTheme,required this.onLanguage,required this.onNotifications,required this.onProfile,required this.onLogout});
  @override State<Shell> createState()=>_ShellState();
}
class _ShellState extends State<Shell>{
  int tab=0;
  Future<void> openChat(Chat x)async{
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatPage(chat:x)));
  }
  Future<void> openPerson(UserX u)async{
    try{
      final d=await Api.post('/chats/direct',{'userId':u.id});
      final chat=Chat((d['id']??'').toString(),u.name,(d['preview']??'').toString(),'');
      if(mounted)await openChat(chat);
    }catch(e){
      if(!mounted)return;
      final msg=e.toString().contains('cannot_chat_self')?(S(context).ru?'Нельзя открыть чат с собой.':'You cannot chat with yourself.'):S(context).openChatError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));
    }
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    final current=tab==0
      ?Chats(onOpen:openChat,onNewChat:()=>setState(()=>tab=1))
      :tab==1
        ?Contacts(onOpen:openPerson)
        :tab==2
          ?const Calls()
          :Settings(
              name:widget.name,
              username:widget.username,
              light:widget.light,
              language:widget.language,
              notifications:widget.notifications,
              onTheme:widget.onTheme,
              onLanguage:widget.onLanguage,
              onNotifications:widget.onNotifications,
              onProfile:widget.onProfile,
              onLogout:widget.onLogout,
            );
    return Scaffold(
      extendBody:true,
      backgroundColor:bg,
      body:SafeArea(
        bottom:false,
        child:Stack(
          children:[
            const Positioned.fill(child:VibeAnimatedBackground()),
            Positioned.fill(
              child:AnimatedSwitcher(
                duration:const Duration(milliseconds:260),
                switchInCurve:Curves.easeOutCubic,
                switchOutCurve:Curves.easeInCubic,
                layoutBuilder:(currentChild,previousChildren)=>Stack(
                  alignment:Alignment.topCenter,
                  children:[
                    ...previousChildren,
                    if(currentChild!=null)currentChild,
                  ],
                ),
                transitionBuilder:(child,animation)=>FadeTransition(
                  opacity:animation,
                  child:SlideTransition(position:Tween<Offset>(begin:const Offset(.018,0),end:Offset.zero).animate(CurvedAnimation(parent:animation,curve:Curves.easeOutCubic)),child:child),
                ),
                child:KeyedSubtree(key:ValueKey(tab),child:current),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:SafeArea(
        top:false,
        child:Padding(
          padding:const EdgeInsets.fromLTRB(14,8,14,10),
          child:Container(
            height:66,
            decoration:BoxDecoration(
              color:const Color(0xFF0C0C13).withOpacity(.88),
              borderRadius:BorderRadius.circular(24),
              border:Border.all(color:stroke.withOpacity(.9)),
              boxShadow:[BoxShadow(color:pink.withOpacity(.10),blurRadius:28,spreadRadius:-8,offset:const Offset(0,8))],
            ),
            child:Row(
              children:[
                _NavItem(icon:Icons.chat_bubble_outline_rounded,activeIcon:Icons.chat_bubble_rounded,label:s.chats,active:tab==0,onTap:()=>setState(()=>tab=0)),
                _NavItem(icon:Icons.people_outline_rounded,activeIcon:Icons.people_alt_rounded,label:s.people,active:tab==1,onTap:()=>setState(()=>tab=1)),
                _NavItem(icon:Icons.call_outlined,activeIcon:Icons.call_rounded,label:s.calls,active:tab==2,onTap:()=>setState(()=>tab=2)),
                _NavItem(icon:Icons.tune_rounded,activeIcon:Icons.tune_rounded,label:s.settings,active:tab==3,onTap:()=>setState(()=>tab=3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget{
  final IconData icon,activeIcon;final String label;final bool active;final VoidCallback onTap;
  const _NavItem({required this.icon,required this.activeIcon,required this.label,required this.active,required this.onTap});
  @override Widget build(BuildContext context)=>Expanded(
    child:Material(
      color:Colors.transparent,
      child:InkWell(
        onTap:onTap,
        borderRadius:BorderRadius.circular(19),
        child:AnimatedContainer(
          duration:const Duration(milliseconds:180),
          margin:const EdgeInsets.symmetric(horizontal:3,vertical:6),
          decoration:BoxDecoration(
            gradient:active?LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[const Color(0xFF9B6BFF).withOpacity(.22),const Color(0xFFE76BD0).withOpacity(.16)]):null,
            borderRadius:BorderRadius.circular(19),
            border:active?Border.all(color:pink.withOpacity(.30)):null,
          ),
          child:Column(
            mainAxisAlignment:MainAxisAlignment.center,
            children:[
              Icon(active?activeIcon:icon,size:21,color:active?Colors.white:muted),
              const SizedBox(height:3),
              Text(label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:active?Colors.white:muted)),
            ],
          ),
        ),
      ),
    ),
  );
}

class Chats extends StatefulWidget{
  final Future<void> Function(Chat) onOpen;final VoidCallback onNewChat;
  const Chats({super.key,required this.onOpen,required this.onNewChat});
  @override State<Chats> createState()=>_ChatsState();
}
class _ChatsState extends State<Chats>{
  String q='';bool loading=true;List<Chat> list=[];String? error;int chip=0;
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    try{
      final a=await Api.get('/chats');
      list=(a as List).map((x){
        final lastRaw=(x['last_at']??x['created_at']??'').toString();
        return Chat(
          (x['id']??'').toString(),
          (x['title']??'Chat').toString(),
          (x['preview']??'').toString(),
          shortTime(lastRaw),
          unread:int.tryParse((x['unread']??0).toString())??0,
          isGroup:(x['is_group']??false)==true,
          lastAt:DateTime.tryParse(lastRaw)?.toLocal(),
        );
      }).toList();
      error=null;
    }catch(e){error=e.toString();}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> openTile(Chat x)async{
    await widget.onOpen(x);
    if(mounted)load();
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    final query=q.toLowerCase();
    var filtered=list.where((x)=>x.name.toLowerCase().contains(query)||x.preview.toLowerCase().contains(query)).toList();
    if(chip==1)filtered=filtered.where((x)=>x.unread>0).toList();
    if(chip==2)filtered=filtered.where((x)=>!x.isGroup).toList();
    if(chip==3)filtered=filtered.where((x)=>x.isGroup).toList();
    final totalUnread=list.fold<int>(0,(sum,x)=>sum+x.unread);
    final chips=[s.filterAll,s.filterUnread,s.filterDirect,s.filterGroups];
    return Container(color:bg,child:Stack(
      children:[
        Positioned(top:-170,right:-120,child:_Glow(size:330,color:purple.withOpacity(.12))),
        Positioned(top:100,left:-180,child:_Glow(size:270,color:blue.withOpacity(.045))),
        Positioned(bottom:20,right:-160,child:_Glow(size:290,color:pink.withOpacity(.06))),
        Column(
          children:[
            Padding(
              padding:const EdgeInsets.fromLTRB(22,18,16,8),
              child:Row(
                children:[
                  Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      const _VibeWordmark(fontSize:30),
                      const SizedBox(height:2),
                      Text(s.chats.toLowerCase(),style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.w700,letterSpacing:.7)),
                    ],
                  ),
                  const Spacer(),
                  _SquareAction(icon:Icons.add_rounded,gradient:true,size:52,onTap:widget.onNewChat),
                ],
              ),
            ),
            Padding(
              padding:const EdgeInsets.fromLTRB(22,8,22,10),
              child:SearchBox(hint:s.searchChats,onChanged:(v)=>setState(()=>q=v)),
            ),
            SizedBox(
              height:40,
              child:ListView.separated(
                padding:const EdgeInsets.symmetric(horizontal:22),
                scrollDirection:Axis.horizontal,
                itemCount:chips.length,
                separatorBuilder:(_,__)=>const SizedBox(width:8),
                itemBuilder:(_,i){
                  final active=chip==i;
                  String label=chips[i];
                  if(i==0&&totalUnread>0)label+=' $totalUnread';
                  return GestureDetector(
                    onTap:()=>setState(()=>chip=i),
                    child:AnimatedContainer(
                      duration:const Duration(milliseconds:180),
                      padding:const EdgeInsets.symmetric(horizontal:16),
                      alignment:Alignment.center,
                      decoration:BoxDecoration(
                        gradient:active?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad):null,
                        color:active?null:surface.withOpacity(.6),
                        borderRadius:BorderRadius.circular(13),
                        border:Border.all(color:active?Colors.white.withOpacity(.12):stroke),
                        boxShadow:active?[BoxShadow(color:pink.withOpacity(.20),blurRadius:14,offset:const Offset(0,4))]:null,
                      ),
                      child:Text(label,style:TextStyle(fontSize:12.5,fontWeight:FontWeight.w800,color:active?Colors.white:muted)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height:8),
            Expanded(child:loading
                  ?ListView(children:[const SizedBox(height:170),const Center(child:CircularProgressIndicator(color:pink))])
                  :error!=null
                    ?ListView(
                      physics:const AlwaysScrollableScrollPhysics(),
                      children:[const SizedBox(height:120),EmptyState(icon:Icons.cloud_off_rounded,title:s.connectionError,sub:error!)],
                    )
                  :filtered.isEmpty
                    ?ListView(
                      physics:const AlwaysScrollableScrollPhysics(),
                      children:[const SizedBox(height:125),EmptyState(icon:Icons.forum_outlined,title:s.noChats,sub:s.noChatsSub)],
                    )
                    :ListView.separated(
                      physics:const ClampingScrollPhysics(),
                      padding:const EdgeInsets.fromLTRB(14,2,14,100),
                      itemCount:filtered.length,
                      separatorBuilder:(_,__)=>const SizedBox(height:9),
                      itemBuilder:(_,i)=>_EntryAnimation(
                        delay:Duration(milliseconds:i>7?320:i*45),
                        child:Tile(chat:filtered[i],tap:()=>openTile(filtered[i])),
                      ),
                    ),
            ),
          ],
        ),
      ],
      ),
    );
  }
}

class ChatSearchPage extends StatefulWidget{
  final List<Chat> list;
  const ChatSearchPage({super.key,required this.list});
  @override State<ChatSearchPage> createState()=>_ChatSearchPageState();
}
class _ChatSearchPageState extends State<ChatSearchPage>{
  final controller=TextEditingController();
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final s=S(context);
    final q=controller.text.trim().toLowerCase();
    final filtered=widget.list.where((x)=>x.name.toLowerCase().contains(q)||x.preview.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor:bg,
      appBar:AppBar(
        backgroundColor:bg,
        titleSpacing:0,
        leading:IconButton(
          onPressed:()=>Navigator.pop(context),
          icon:const Icon(Icons.arrow_back_rounded),
        ),
        title:Padding(
          padding:const EdgeInsets.only(right:12),
          child:SearchBox(controller:controller,hint:s.searchChats,onChanged:(_)=>setState((){})),
        ),
      ),
      body:filtered.isEmpty
        ?ListView(
            physics:const AlwaysScrollableScrollPhysics(),
            children:[const SizedBox(height:125),EmptyState(icon:Icons.search_off_rounded,title:s.noChats,sub:s.noChatsSub)],
          )
        :ListView.separated(
            padding:const EdgeInsets.fromLTRB(14,8,14,24),
            itemCount:filtered.length,
            separatorBuilder:(_,__)=>const SizedBox(height:9),
            itemBuilder:(_,i)=>Tile(chat:filtered[i],tap:()=>Navigator.pop(context,filtered[i])),
          ),
    );
  }
}

class SearchBox extends StatelessWidget{
  final TextEditingController? controller;final String hint;final ValueChanged<String>? onChanged;
  const SearchBox({super.key,this.controller,required this.hint,this.onChanged});
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Container(
      height:48,
      decoration:BoxDecoration(
        color:dark?surface.withOpacity(.65):Colors.white,
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:dark?stroke:Colors.black12),
      ),
      padding:const EdgeInsets.only(left:14,right:8),
      child:Row(
        children:[
          Icon(Icons.search_rounded,color:muted,size:21),
          const SizedBox(width:9),
          Expanded(child:_BareField(controller:controller,hint:hint,onChanged:onChanged)),
        ],
      ),
    );
  }
}

class _BareField extends StatefulWidget{
  final TextEditingController? controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  const _BareField({this.controller,required this.hint,this.icon,this.keyboardType,this.maxLines=1,this.onChanged});
  @override State<_BareField> createState()=>_BareFieldState();
}
class _BareFieldState extends State<_BareField>{
  late final TextEditingController controller;
  late final FocusNode focusNode;
  bool ownController=false;
  @override void initState(){
    super.initState();
    if(widget.controller!=null){
      controller=widget.controller!;
    }else{
      controller=TextEditingController();
      ownController=true;
    }
    focusNode=FocusNode();
  }
  @override void dispose(){
    focusNode.dispose();
    if(ownController)controller.dispose();
    super.dispose();
  }
  @override Widget build(BuildContext context){
    final multi=widget.maxLines>1;
    return SizedBox(
      height:multi?null:50,
      width:double.infinity,
      child:Row(
        crossAxisAlignment:multi?CrossAxisAlignment.start:CrossAxisAlignment.center,
        children:[
          if(widget.icon!=null)Padding(
            padding:EdgeInsets.only(left:0,right:9,top:multi?14:0),
            child:Icon(widget.icon,color:muted,size:21),
          ),
          Expanded(
            child:Stack(
              alignment:multi?Alignment.topLeft:Alignment.centerLeft,
              children:[
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable:controller,
                  builder:(context,value,_){
                    if(value.text.isNotEmpty)return const SizedBox.shrink();
                    return IgnorePointer(
                      child:Padding(
                        padding:EdgeInsets.only(top:multi?14:0),
                        child:Text(widget.hint,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:15,fontWeight:FontWeight.w500)),
                      ),
                    );
                  },
                ),
                EditableText(
                  controller:controller,
                  focusNode:focusNode,
                  obscureText:false,
                  keyboardType:widget.keyboardType??(multi?TextInputType.multiline:TextInputType.text),
                  textInputAction:multi?TextInputAction.newline:TextInputAction.done,
                  maxLines:multi?widget.maxLines:1,
                  minLines:1,
                  style:const TextStyle(fontWeight:FontWeight.w600,fontSize:15),
                  cursorColor:pink,
                  backgroundCursorColor:muted,
                  selectionColor:pink.withOpacity(.25),
                  onChanged:widget.onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _GlassSearchField extends StatelessWidget{
  final String hint;
  final ValueChanged<String> onChanged;
  const _GlassSearchField({required this.hint,required this.onChanged});
  @override Widget build(BuildContext context)=>SearchBox(hint:hint,onChanged:onChanged);
}

String _fmtTime(DateTime d)=>d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');
String shortTime(String raw){
  final d=DateTime.tryParse(raw)?.toLocal();
  if(d==null)return '';
  final now=DateTime.now();
  if(d.year==now.year&&d.month==now.month&&d.day==now.day)return _fmtTime(d);
  const m=['янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'];
  return d.day.toString()+' '+m[d.month-1];
}

class Tile extends StatelessWidget{
  final Chat chat;final VoidCallback tap;
  const Tile({super.key,required this.chat,required this.tap});
  @override Widget build(BuildContext context){
    final s=S(context);
    return Material(
      type:MaterialType.transparency,
      child:InkWell(
        onTap:tap,
        borderRadius:BorderRadius.circular(22),
        splashColor:pink.withOpacity(.06),
        highlightColor:pink.withOpacity(.035),
        child:Container(
          padding:const EdgeInsets.symmetric(horizontal:6,vertical:11),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(22),
            border:Border(bottom:BorderSide(color:stroke.withOpacity(.52),width:.7)),
          ),
          child:Row(
            children:[
              Avatar(name:chat.name,size:54),
              const SizedBox(width:12),
              Expanded(
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(chat.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15.5,fontWeight:FontWeight.w800)),
                    const SizedBox(height:4),
                    Text(chat.preview.isEmpty?s.active:chat.preview,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:13)),
                  ],
                ),
              ),
              const SizedBox(width:10),
              Column(
                mainAxisAlignment:MainAxisAlignment.center,
                crossAxisAlignment:CrossAxisAlignment.end,
                children:[
                  if(chat.time.isNotEmpty)Text(chat.time,style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.w700)),
                  const SizedBox(height:7),
                  if(chat.unread>0)
                    Container(
                      constraints:const BoxConstraints(minWidth:23),
                      height:23,
                      padding:const EdgeInsets.symmetric(horizontal:7),
                      alignment:Alignment.center,
                      decoration:BoxDecoration(
                        gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),
                        borderRadius:BorderRadius.circular(8),
                        boxShadow:[BoxShadow(color:pink.withOpacity(.35),blurRadius:10,offset:const Offset(0,3))],
                      ),
                      child:Text(chat.unread>99?'99+':chat.unread.toString(),style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900)),
                    )
                  else
                    const SizedBox(height:23),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget{
  final String name;final double size;
  const Avatar({super.key,required this.name,this.size=46});
  @override Widget build(BuildContext context){
    const colors=[purple,pink,blue,green];final i=name.isEmpty?0:name.codeUnitAt(0)%colors.length;
    return Container(
      width:size,height:size,alignment:Alignment.center,
      decoration:BoxDecoration(
        borderRadius:BorderRadius.circular(size*.32),
        gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[colors[i],colors[(i+1)%colors.length]]),
        border:Border.all(color:Colors.white.withOpacity(.16),width:1),
        boxShadow:[BoxShadow(color:colors[i].withOpacity(.28),blurRadius:16,spreadRadius:-2)],
      ),
      child:Text(name.isEmpty?'?':name[0].toUpperCase(),style:TextStyle(color:Colors.white,fontSize:size*.36,fontWeight:FontWeight.w900)),
    );
  }
}
class ChatPage extends StatefulWidget{
  final Chat chat;const ChatPage({super.key,required this.chat});@override State<ChatPage> createState()=>_ChatState();
}
class _ChatState extends State<ChatPage>{
  final input=TextEditingController();final scroll=ScrollController();List<Msg> msgs=[];
  final recorder=AudioRecorder();
  bool loading=true,sending=false,peerTyping=false,peerOnline=false;IO.Socket? socket;String myId='',peerId='';
  int effect=0;double fxIntensity=.55;Timer? typingTimer,typingClear;

  @override void initState(){super.initState();load();restoreFx();}
  @override void dispose(){socket?.disconnect();socket?.dispose();recorder.dispose();input.dispose();scroll.dispose();typingTimer?.cancel();typingClear?.cancel();super.dispose();}
  Future<void> restoreFx()async{
    final p=await SharedPreferences.getInstance();
    if(!mounted)return;
    setState((){
      effect=p.getInt('fx_'+widget.chat.id)??0;
      fxIntensity=p.getDouble('fxi_'+widget.chat.id)??0.55;
    });
  }
  Future<void> saveFx()async{
    final p=await SharedPreferences.getInstance();
    await p.setInt('fx_'+widget.chat.id,effect);
    await p.setDouble('fxi_'+widget.chat.id,fxIntensity);
  }
  Future<void> load()async{
    try{
      final me=await Api.get('/me');myId=(me['id']??'').toString();
      final a=await Api.get('/chats/'+widget.chat.id+'/messages');
      msgs=(a as List).map((x)=>Msg(
        (x['id']??'').toString(),
        (x['body']??'').toString(),
        (x['sender_name']??'').toString(),
        (x['sender_id']??'').toString()==myId,
        type:(x['message_type']??'text').toString(),
        mediaUrl:(x['media_url']??'').toString(),
        createdAt:DateTime.tryParse((x['created_at']??'').toString())?.toLocal(),
      )).toList();
      connectRealtime();
      markRead();
      try{
        final pr=await Api.get('/chats/'+widget.chat.id+'/peer');
        peerId=(pr['id']??'').toString();
        if(peerId.isNotEmpty&&mounted)setState((){});
      }catch(_){}
    }catch(_){}
    if(mounted){setState(()=>loading=false);WidgetsBinding.instance.addPostFrameCallback((_)=>scrollEnd());}
  }
  Future<void> markRead()async{try{await Api.post('/chats/'+widget.chat.id+'/read',{});}catch(_){}}
  Future<void> connectRealtime()async{
    final t=await Api.token();if(t==null)return;
    socket=IO.io(apiBase,IO.OptionBuilder().setTransports(['websocket']).setAuth({'token':t}).disableAutoConnect().build());
    socket!.onConnect((_){socket!.emit('joinChat',widget.chat.id);socket!.emit('presence',true);});
    socket!.on('message',(data){
      if(!mounted||data is! Map)return;
      final id=(data['id']??'').toString();if(id.isEmpty||msgs.any((m)=>m.id==id))return;
      setState(()=>msgs.add(Msg(
        id,
        (data['body']??'').toString(),
        (data['sender_name']??'').toString(),
        (data['sender_id']??'').toString()==myId,
        type:(data['message_type']??'text').toString(),
        mediaUrl:(data['media_url']??'').toString(),
        createdAt:DateTime.tryParse((data['created_at']??'').toString())?.toLocal(),
      )));
      markRead();
      WidgetsBinding.instance.addPostFrameCallback((_)=>scrollEnd());
    });
    socket!.on('typing',(data){
      if(!mounted||data is! Map)return;
      if(((data['chatId']??'').toString())!=widget.chat.id)return;
      if(((data['userId']??'').toString())==myId)return;
      final typing=data['typing']==true;
      if(typing!=peerTyping)setState(()=>peerTyping=typing);
      typingClear?.cancel();
      if(typing)typingClear=Timer(const Duration(seconds:4),(){if(mounted)setState(()=>peerTyping=false);});
    });
    socket!.on('presence',(data){
      if(!mounted||data is! Map)return;
      if(((data['userId']??'').toString())!=myId&&peerId.isNotEmpty&&((data['userId']??'').toString())==peerId){
        setState(()=>peerOnline=data['online']==true);
      }
    });
    socket!.connect();
  }
  void onInputChanged(String v){
    typingTimer?.cancel();
    socket?.emit('typing',{'chatId':widget.chat.id,'typing':true});
    typingTimer=Timer(const Duration(milliseconds:2200),(){socket?.emit('typing',{'chatId':widget.chat.id,'typing':false});});
  }
  Future<void> send()async{
    final body=input.text.trim();if(body.isEmpty||sending)return;
    await sendMediaMessage(body:body,type:'text');
    if(mounted)input.clear();
  }
  Future<void> sendMediaMessage({required String body,required String type,String mediaUrl=''})async{
    if(sending)return;
    setState(()=>sending=true);
    try{
      final x=await Api.post('/chats/'+widget.chat.id+'/messages',{'body':body,'type':type,'mediaUrl':mediaUrl});
      final id=(x['id']??DateTime.now().microsecondsSinceEpoch).toString();
      final sender=(x['sender_name']??'').toString();
      if(mounted&&!msgs.any((m)=>m.id==id)){
        setState(()=>msgs.add(Msg(id,body,sender,true,type:type,mediaUrl:mediaUrl,createdAt:DateTime.tryParse((x['created_at']??'').toString())?.toLocal())));
      }
      if(socket?.connected==true){
        socket!.emit('message',{'chatId':widget.chat.id,'body':body,'type':type,'mediaUrl':mediaUrl,'clientId':id});
      }
      WidgetsBinding.instance.addPostFrameCallback((_)=>scrollEnd());
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(type=='text'?S(context).messageNotSent:S(context).mediaFailed)));
    }finally{if(mounted)setState(()=>sending=false);}
  }
  Future<void> pickMedia()async{
    try{
      final file=await ImagePicker().pickMedia();
      if(file==null)return;
      final bytes=await file.readAsBytes();
      if(bytes.length>7*1024*1024){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).mediaTooLarge)));
        return;
      }
      final lower=file.name.toLowerCase();
      final type=(lower.endsWith('.mp4')||lower.endsWith('.mov')||lower.endsWith('.mkv')||lower.endsWith('.webm'))?'video':'image';
      final mime=type=='video'?'video/mp4':'image/jpeg';
      await sendMediaMessage(body:type=='video'?'🎥 '+file.name:'📷 '+file.name,type:type,mediaUrl:'data:'+mime+';base64,'+base64Encode(bytes));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).mediaFailed)));
    }
  }
  Future<void> recordVoice()async{
    try{
      if(!await recorder.hasPermission()){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).mediaFailed)));
        return;
      }
      final dir=await getTemporaryDirectory();
      final path=dir.path+'/vibe_'+DateTime.now().millisecondsSinceEpoch.toString()+'.m4a';
      await recorder.start(const RecordConfig(),path:path);
      if(!mounted)return;
      final action=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:Text(S(context).recording),
        content:const Icon(Icons.mic_rounded,size:56,color:pink),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(S(context).cancelRecording)),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(S(context).stopAndSend)),
        ],
      ));
      if(action==true){
        final recorded=await recorder.stop();
        if(recorded!=null){
          final bytes=await XFile(recorded).readAsBytes();
          if(bytes.length<=7*1024*1024){
            await sendMediaMessage(body:'🎤 '+S(context).voiceMessage,type:'audio',mediaUrl:'data:audio/mp4;base64,'+base64Encode(bytes));
          }else if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).mediaTooLarge)));
        }
      }else{
        await recorder.cancel();
      }
    }catch(_){
      try{await recorder.cancel();}catch(_){}
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).mediaFailed)));
    }
  }
  void scrollEnd(){if(!scroll.hasClients)return;scroll.animateTo(scroll.position.maxScrollExtent,duration:const Duration(milliseconds:220),curve:Curves.easeOut);}
  void showEffects(BuildContext context){
    showModalBottomSheet(
      context:context,
      isScrollControlled:true,
      backgroundColor:Colors.transparent,
      builder:(_)=>_EffectsSheet(initial:effect,intensity:fxIntensity,onChanged:(e,i){
        setState((){
          effect=e;
          fxIntensity=i;
        });
        saveFx();
      }),
    );
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    final dark=Theme.of(context).brightness==Brightness.dark;
    final pageBg=dark?bg:const Color(0xFFF3F1FA);
    final chatSurface=dark?surface:Colors.white;
    return Theme(
      data:Theme.of(context).copyWith(
        scaffoldBackgroundColor:pageBg,
        canvasColor:pageBg,
        colorScheme:Theme.of(context).colorScheme.copyWith(
          surface:chatSurface,
          surfaceContainerLowest:pageBg,
          surfaceContainerLow:pageBg,
          surfaceContainer:chatSurface,
          surfaceContainerHigh:chatSurface,
          surfaceContainerHighest:chatSurface,
        ),
        cardColor:chatSurface,
      ),
      child:Scaffold(
        backgroundColor:pageBg,
        body:Column(children:[
          SafeArea(
            bottom:false,
            child:Container(
              height:70,
              color:pageBg,
              padding:const EdgeInsets.symmetric(horizontal:4),
              child:Row(
                children:[
                  SizedBox(
                    width:46,
                    height:56,
                    child:IconButton(
                      tooltip:MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed:()=>Navigator.maybePop(context),
                      icon:const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Expanded(
                    child:Material(
                      type:MaterialType.transparency,
                      child:InkWell(
                        borderRadius:BorderRadius.circular(16),
                        onTap:()=>showContact(context),
                        child:Padding(
                          padding:const EdgeInsets.symmetric(horizontal:5,vertical:5),
                          child:Row(
                            children:[
                              Avatar(name:widget.chat.name,size:40),
                              const SizedBox(width:10),
                              Expanded(
                                child:Column(
                                  mainAxisAlignment:MainAxisAlignment.center,
                                  crossAxisAlignment:CrossAxisAlignment.start,
                                  children:[
                                    Text(widget.chat.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
                                    const SizedBox(height:2),
                                    Text(
                                      peerTyping?s.typingNow:(peerOnline||widget.chat.online)?s.online:s.active,
                                      style:TextStyle(color:peerTyping?pink:(peerOnline||widget.chat.online)?purple:muted,fontSize:11,fontWeight:peerTyping?FontWeight.w800:FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip:s.voiceCall,
                    onPressed:()=>openCall(context,false),
                    icon:const Icon(Icons.call_outlined,size:22),
                  ),
                  IconButton(
                    tooltip:s.videoCall,
                    onPressed:()=>openCall(context,true),
                    icon:const Icon(Icons.videocam_outlined,size:22),
                  ),
                  IconButton(
                    tooltip:s.profile,
                    onPressed:()=>showChatMenu(context),
                    icon:const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child:Container(
              color:pageBg,
              child:Stack(
                children:[
                  Positioned.fill(child:IgnorePointer(child:CustomPaint(painter:_EffectPainter(effect:effect,intensity:fxIntensity,dark:dark)))),
                  loading
                    ?const Center(child:CircularProgressIndicator())
                    :msgs.isEmpty
                      ?EmptyState(icon:Icons.auto_awesome_outlined,title:s.joinVibe,sub:s.noChatsSub)
                      :ListView.builder(
                        controller:scroll,
                        padding:const EdgeInsets.fromLTRB(14,18,14,14),
                        itemCount:msgs.length+(peerTyping?1:0),
                        itemBuilder:(_,i){
                          if(i==msgs.length){
                            return Align(
                              alignment:Alignment.centerLeft,
                              child:Padding(padding:const EdgeInsets.only(bottom:7),child:_TypingBubble()),
                            );
                          }
                          final showChip=i==0||_dayKey(msgs[i-1].createdAt)!=_dayKey(msgs[i].createdAt);
                          return Column(children:[
                            if(showChip)_DateChip(d:msgs[i].createdAt),
                            Bubble(key:ValueKey(msgs[i].id),msg:msgs[i]),
                          ]);
                        },
                      ),
                ],
              ),
            ),
          ),
          SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(10,6,10,10),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
            _SquareAction(icon:Icons.add_rounded,onTap:()=>showAttachments(context)),
            const SizedBox(width:8),
            Expanded(child:Container(
              decoration:BoxDecoration(
                color:dark?surface2:Colors.white,
                borderRadius:BorderRadius.circular(20),
                border:Border.all(color:dark?stroke:Colors.black12),
              ),
              padding:const EdgeInsets.symmetric(horizontal:14,vertical:1),
              child:_BareField(controller:input,hint:s.messageHint,maxLines:5,onChanged:onInputChanged),
            )),
            const SizedBox(width:8),
            _SquareAction(icon:Icons.auto_awesome_rounded,gradient:true,busy:sending,onTap:send),
          ]))),
        ]),
      ),
    );
  }
  String _dayKey(DateTime d)=>d.year.toString().padLeft(4,'0')+d.month.toString().padLeft(2,'0')+d.day.toString().padLeft(2,'0');
  Future<void> showContact(BuildContext context)async{
    final s=S(context);
    String username='';
    try{
      final d=await Api.get('/chats/'+widget.chat.id+'/peer');
      username=(d['username']??'').toString();
    }catch(_){}
    if(!context.mounted)return;
    showModalBottomSheet(
      context:context,
      showDragHandle:true,
      builder:(_)=>SafeArea(
        child:Padding(
          padding:const EdgeInsets.fromLTRB(20,8,20,24),
          child:Column(
            mainAxisSize:MainAxisSize.min,
            children:[
              Avatar(name:widget.chat.name,size:84),
              const SizedBox(height:12),
              Text(widget.chat.name,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
              if(username.isNotEmpty) ...[
                const SizedBox(height:4),
                Text('@'+username,style:const TextStyle(color:muted,fontSize:14)),
              ],
              const SizedBox(height:15),
              ListTile(leading:const Icon(Icons.auto_awesome_rounded),title:Text(s.effects),subtitle:Text(s.intensity,style:const TextStyle(color:muted)),onTap:(){Navigator.pop(context);showEffects(context);}),
              ListTile(leading:const Icon(Icons.call_outlined),title:Text(s.voiceCall),onTap:(){Navigator.pop(context);openCall(context,false);}),
              ListTile(leading:const Icon(Icons.videocam_outlined),title:Text(s.videoCall),onTap:(){Navigator.pop(context);openCall(context,true);}),
              ListTile(leading:const Icon(Icons.refresh_rounded),title:Text(s.refresh),onTap:(){Navigator.pop(context);setState(()=>loading=true);load();}),
            ],
          ),
        ),
      ),
    );
  }
  void showChatMenu(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.person_outline_rounded),title:Text(s.profile),onTap:(){Navigator.pop(context);showContact(context);}),
      ListTile(leading:const Icon(Icons.auto_awesome_rounded),title:Text(s.effects),onTap:(){Navigator.pop(context);showEffects(context);}),
      ListTile(leading:const Icon(Icons.refresh_rounded),title:Text(s.refresh),onTap:(){Navigator.pop(context);setState(()=>loading=true);load();}),
    ])));
  }
  void showAttachments(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.photo_library_outlined),title:Text(s.photoVideo),onTap:(){Navigator.pop(context);pickMedia();}),
      ListTile(leading:const Icon(Icons.mic_none_rounded),title:Text(s.voiceMessage),onTap:(){Navigator.pop(context);recordVoice();}),
    ])));
  }
  void openCall(BuildContext context,bool video)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CallPage(name:widget.chat.name,video:video)));
}

class _DateChip extends StatelessWidget{
  final DateTime d;
  const _DateChip({required this.d});
  @override Widget build(BuildContext context){
    final s=S(context);
    const mRu=['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    const mEn=['January','February','March','April','May','June','July','August','September','October','November','December'];
    final now=DateTime.now();
    String txt;
    if(s.ru){txt=d.day.toString()+' '+mRu[d.month-1];}
    else{txt=mEn[d.month-1]+' '+d.day.toString();}
    if(d.year!=now.year)txt+=' '+d.year.toString();
    return Center(
      child:Container(
        margin:const EdgeInsets.only(bottom:12),
        padding:const EdgeInsets.symmetric(horizontal:13,vertical:5),
        decoration:BoxDecoration(color:bg.withOpacity(.72),borderRadius:BorderRadius.circular(12),border:Border.all(color:stroke.withOpacity(.8))),
        child:Text(txt,style:const TextStyle(color:muted,fontSize:11.5,fontWeight:FontWeight.w700)),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget{
  @override State<_TypingBubble> createState()=>_TypingBubbleState();
}
class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  @override void initState(){super.initState();controller=AnimationController(vsync:this,duration:const Duration(milliseconds:900))..repeat();}
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return AnimatedBuilder(
      animation:controller,
      builder:(context,_){
        Widget dot(int i){
          final phase=(controller.value*3-i*.5)%1;
          final up=math.sin(phase*math.pi);
          return Transform.translate(
            offset:Offset(0,-3.2*up),
            child:Container(width:7,height:7,decoration:BoxDecoration(shape:BoxShape.circle,color:(dark?muted:pink).withOpacity(.45+.5*up))),
          );
        }
        return Container(
          padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),
          decoration:BoxDecoration(
            color:dark?surface2:Colors.white,
            borderRadius:const BorderRadius.only(topLeft:Radius.circular(18),topRight:Radius.circular(18),bottomLeft:Radius.circular(5),bottomRight:Radius.circular(18)),
            border:Border.all(color:dark?stroke:Colors.black12),
          ),
          child:Row(mainAxisSize:MainAxisSize.min,children:[dot(0),const SizedBox(width:5),dot(1),const SizedBox(width:5),dot(2)]),
        );
      },
    );
  }
}

class Bubble extends StatefulWidget{
  final Msg msg;const Bubble({super.key,required this.msg});
  @override State<Bubble> createState()=>_BubbleState();
}
class _BubbleState extends State<Bubble> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  late final Animation<double> scale;
  @override void initState(){
    super.initState();
    controller=AnimationController(vsync:this,duration:const Duration(milliseconds:280));
    scale=Tween<double>(begin:.90,end:1).animate(CurvedAnimation(parent:controller,curve:Curves.easeOutBack));
    controller.forward();
  }
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    final msg=widget.msg;
    final cs=Theme.of(context).colorScheme;
    final incoming=dark?surface2:Colors.white;
    final time=_fmtTime(msg.createdAt);
    Widget content;
    if(msg.type=='image'&&msg.mediaUrl.isNotEmpty){
      content=Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
        ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(msg.mediaUrl.substring(msg.mediaUrl.indexOf(',')+1)),width:230,height:230,fit:BoxFit.cover)),
        const SizedBox(height:5),
        _MsgMeta(time:time,mine:msg.mine,dark:dark),
      ]);
    }else{
      content=Row(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.end,children:[
        if(msg.type=='video')const Icon(Icons.videocam_rounded,size:20,color:Colors.white),
        if(msg.type=='audio')const Icon(Icons.mic_rounded,size:20,color:Colors.white),
        if(msg.type!='text')const SizedBox(width:7),
        Flexible(child:Text(msg.text,style:TextStyle(color:msg.mine?Colors.white:cs.onSurface,fontSize:15,height:1.3))),
        const SizedBox(width:8),
        _MsgMeta(time:time,mine:msg.mine,dark:dark),
      ]);
    }
    return Align(
      alignment:msg.mine?Alignment.centerRight:Alignment.centerLeft,
      child:FadeTransition(
        opacity:CurvedAnimation(parent:controller,curve:Curves.easeOut),
        child:ScaleTransition(
          scale:scale,
          child:Container(
            constraints:const BoxConstraints(maxWidth:325),
            margin:const EdgeInsets.only(bottom:7),
            padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
            decoration:BoxDecoration(
              gradient:msg.mine?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad):null,
              color:msg.mine?null:incoming,
              borderRadius:BorderRadius.only(topLeft:const Radius.circular(18),topRight:const Radius.circular(18),bottomLeft:Radius.circular(msg.mine?18:5),bottomRight:Radius.circular(msg.mine?5:18)),
              border:msg.mine?null:Border.all(color:dark?stroke:Colors.black12),
              boxShadow:msg.mine?[BoxShadow(color:pink.withOpacity(.22),blurRadius:14,offset:const Offset(0,5))]:null,
            ),
            child:content,
          ),
        ),
      ),
    );
  }
}

class _MsgMeta extends StatelessWidget{
  final String time;final bool mine;final bool dark;
  const _MsgMeta({required this.time,required this.mine,required this.dark});
  @override Widget build(BuildContext context){
    return Row(mainAxisSize:MainAxisSize.min,children:[
      Text(time,style:TextStyle(color:mine?Colors.white.withOpacity(.75):muted,fontSize:10.5,fontWeight:FontWeight.w700)),
      if(mine) ...[
        const SizedBox(width:3),
        Icon(Icons.done_all_rounded,size:13,color:Colors.white.withOpacity(.75)),
      ],
    ]);
  }
}

class _EffectsSheet extends StatefulWidget{
  final int initial;final double intensity;final void Function(int,double) onChanged;
  const _EffectsSheet({required this.initial,required this.intensity,required this.onChanged});
  @override State<_EffectsSheet> createState()=>_EffectsSheetState();
}
class _EffectsSheetState extends State<_EffectsSheet>{
  late int sel;late double intensity;
  @override void initState(){super.initState();sel=widget.initial;intensity=widget.intensity;}
  @override Widget build(BuildContext context){
    final s=S(context);
    final names=s.ru?const['сердце','звёзды','кибер','неон','пламя','градиент','пиксели','пузырьки','y2k']:const['heart','stars','cyber','neon','flame','gradient','pixels','bubbles','y2k'];
    const icons=[Icons.favorite_rounded,Icons.auto_awesome_rounded,Icons.developer_board_rounded,Icons.blur_on_rounded,Icons.local_fire_department_rounded,Icons.gradient_rounded,Icons.grid_view_rounded,Icons.bubble_chart_rounded,Icons.flare_rounded];
    return Container(
      decoration:BoxDecoration(color:Theme.of(context).cardTheme.color,borderRadius:const BorderRadius.vertical(top:Radius.circular(28)),border:Border(top:BorderSide(color:stroke))),
      padding:const EdgeInsets.fromLTRB(18,6,18,24),
      child:SafeArea(
        top:false,
        child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Row(children:[
              Text(s.effects,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
              const Spacer(),
              IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height:8),
            GridView.count(
              crossAxisCount:3,
              shrinkWrap:true,
              physics:const NeverScrollableScrollPhysics(),
              mainAxisSpacing:10,
              crossAxisSpacing:10,
              childAspectRatio:1.02,
              children:List.generate(9,(i){
                final active=sel==i;
                return Material(
                  color:Colors.transparent,
                  child:InkWell(
                    onTap:(){
                      setState(()=>sel=i);
                      widget.onChanged(i,intensity);
                    },
                    borderRadius:BorderRadius.circular(18),
                    child:AnimatedContainer(
                      duration:const Duration(milliseconds:160),
                      decoration:BoxDecoration(
                        color:active?purple.withOpacity(.10):surface2.withOpacity(.6),
                        borderRadius:BorderRadius.circular(18),
                        border:Border.all(color:active?pink.withOpacity(.55):stroke),
                        boxShadow:active?[BoxShadow(color:pink.withOpacity(.20),blurRadius:16,offset:const Offset(0,4))]:null,
                      ),
                      child:Column(
                        mainAxisAlignment:MainAxisAlignment.center,
                        children:[
                          Icon(icons[i],size:28,color:active?pink:muted),
                          const SizedBox(height:7),
                          Text(names[i],style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:active?Colors.white:muted)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height:16),
            Text(s.intensity,style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.1)),
            Slider(
              value:intensity,
              min:.1,max:1,
              onChanged:(v)=>setState(()=>intensity=v),
              onChangeEnd:(v)=>widget.onChanged(sel,v),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectPainter extends CustomPainter{
  final int effect;final double intensity;final bool dark;
  _EffectPainter({required this.effect,required this.intensity,required this.dark});
  double get k{final v=intensity;return v < .1 ? .1 : (v > 1 ? 1 : v);}
  Color get cPink=>dark?pink:pink.withOpacity(.9);
  Color get cPurple=>dark?purple:purple.withOpacity(.9);
  Color get cWhite=>dark?Colors.white:const Color(0xFF6B5CA8);
  @override void paint(Canvas canvas,Size size){
    switch(effect){
      case 0:_heart(canvas,size);break;
      case 1:_stars(canvas,size);break;
      case 2:_cyber(canvas,size);break;
      case 3:_neon(canvas,size);break;
      case 4:_flame(canvas,size);break;
      case 5:_gradient(canvas,size);break;
      case 6:_pixels(canvas,size);break;
      case 7:_bubbles(canvas,size);break;
      default:_y2k(canvas,size);break;
    }
    if(effect!=5)_sparkles(canvas,size,effect==1?26:12);
  }
  void _grid(Canvas canvas,Size size,{double op=.05,double step=38}){
    final p=Paint()..color=cWhite.withOpacity(dark ? .035*k : .05*k)..strokeWidth=.6;
    for(double x=0;x<size.width;x+=step){canvas.drawLine(Offset(x,0),Offset(x,size.height),p);}
    for(double y=0;y<size.height;y+=step){canvas.drawLine(Offset(0,y),Offset(size.width,y),p);}
  }
  void _glowStroke(Canvas canvas,Path path,Color color,double width,double blur){
    final p=Paint()..style=PaintingStyle.stroke..strokeWidth=width..color=color..maskFilter=MaskFilter.blur(BlurStyle.normal,blur);
    canvas.drawPath(path,p);
  }
  Path _heartPath(Offset center,double w){
    final top=center.dy-w*.22;
    return Path()
      ..moveTo(center.dx,top+w*.22)
      ..cubicTo(center.dx-w*.14,top,center.dx-w*.44,top+w*.10,center.dx-w*.48,top+w*.34)
      ..cubicTo(center.dx-w*.52,top+w*.58,center.dx-w*.28,top+w*.76,center.dx,top+w*.95)
      ..cubicTo(center.dx+w*.28,top+w*.76,center.dx+w*.52,top+w*.58,center.dx+w*.48,top+w*.34)
      ..cubicTo(center.dx+w*.44,top+w*.10,center.dx+w*.14,top,center.dx,top+w*.22)
      ..close();
  }
  void _heart(Canvas canvas,Size size){
    _grid(canvas,size);
    final c=Offset(size.width*.5,size.height*.42);
    final path=_heartPath(c,size.width*.62);
    _glowStroke(canvas,path,cPink,3.2,26*k);
    _glowStroke(canvas,path,cPurple,1.4,10);
    final p=Paint()..style=PaintingStyle.stroke..strokeWidth=1.6..shader=LinearGradient(colors:[cPink,cPurple]).createShader(Rect.fromCenter(center:c,width:size.width*.7,height:size.width*.7));
    canvas.drawPath(path,p);
  }
  void _star4(Canvas canvas,Offset c,double r,Color color,double op){
    final path=Path()
      ..moveTo(c.dx,c.dy-r)
      ..quadraticBezierTo(c.dx,c.dy,c.dx+r,c.dy)
      ..quadraticBezierTo(c.dx,c.dy,c.dx,c.dy+r)
      ..quadraticBezierTo(c.dx,c.dy,c.dx-r,c.dy)
      ..quadraticBezierTo(c.dx,c.dy,c.dx,c.dy-r)
      ..close();
    final glow=Paint()..color=color.withOpacity(op*.5)..maskFilter=const MaskFilter.blur(BlurStyle.normal,6);
    canvas.drawPath(path,glow);
    canvas.drawPath(path,Paint()..color=color.withOpacity(op));
  }
  void _sparkles(Canvas canvas,Size size,int count){
    final rnd=math.Random(11);
    for(int i=0;i<count;i++){
      final o=Offset(size.width*rnd.nextDouble(),size.height*rnd.nextDouble());
      final r=2.5+rnd.nextDouble()*7;
      final col=i%3==0?cPink:(i%3==1?cPurple:cWhite);
      _star4(canvas,o,r,col,(.14+.30*rnd.nextDouble())*k);
    }
  }
  void _stars(Canvas canvas,Size size){
    _grid(canvas,size,op:.03);
    final rnd=math.Random(5);
    for(int i=0;i<34;i++){
      final o=Offset(size.width*rnd.nextDouble(),size.height*rnd.nextDouble());
      final r=3+rnd.nextDouble()*13;
      final col=i%2==0?cPurple:cPink;
      _star4(canvas,o,r,col,(.16+.42*rnd.nextDouble())*k);
    }
  }
  void _cyber(Canvas canvas,Size size){
    _grid(canvas,size,op:.09,step:30);
    final p=Paint()..style=PaintingStyle.stroke..strokeWidth=1.2..color=cPink.withOpacity(.20*k);
    canvas.drawCircle(Offset(size.width*.72,size.height*.30),54,p);
    canvas.drawCircle(Offset(size.width*.72,size.height*.30),82,p);
    final p2=Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=cPurple.withOpacity(.22*k);
    canvas.drawLine(Offset(0,size.height*.30),Offset(size.width,size.height*.30),p2);
    canvas.drawLine(Offset(size.width*.72,0),Offset(size.width*.72,size.height),p2);
    canvas.drawCircle(Offset(size.width*.72,size.height*.30),4,Paint()..color=cPink.withOpacity(.55*k));
  }
  void _neon(Canvas canvas,Size size){
    final rnd=math.Random(9);
    for(int i=0;i<7;i++){
      final o=Offset(size.width*rnd.nextDouble(),size.height*rnd.nextDouble());
      final r=44+rnd.nextDouble()*95;
      final col=[cPink,cPurple,blue][i%3];
      final paint=Paint()..color=col.withOpacity(.085*k)..maskFilter=MaskFilter.blur(BlurStyle.normal,44*k);
      canvas.drawCircle(o,r,paint);
    }
  }
  void _flame(Canvas canvas,Size size){
    for(int i=0;i<5;i++){
      final x=size.width*(.12+.19*i);
      final h=size.height*(.16+.05*((i*2)%3));
      final base=Offset(x,size.height+8);
      final path=Path()
        ..moveTo(base.dx,base.dy)
        ..quadraticBezierTo(base.dx-h*.32,base.dy-h*.6,base.dx,base.dy-h)
        ..quadraticBezierTo(base.dx+h*.32,base.dy-h*.6,base.dx,base.dy)
        ..close();
      final col=i%2==0?cPink:cPurple;
      final paint=Paint()..color=col.withOpacity(.10*k)..maskFilter=MaskFilter.blur(BlurStyle.normal,22*k);
      canvas.drawPath(path,paint);
    }
  }
  void _gradient(Canvas canvas,Size size){
    final rects=[
      [Offset(size.width*.2,size.height*.2),cPink],
      [Offset(size.width*.8,size.height*.35),cPurple],
      [Offset(size.width*.5,size.height*.8),blue],
    ];
    for(final r in rects){
      final paint=Paint()..color=(r[1] as Color).withOpacity(.10*k)..maskFilter=MaskFilter.blur(BlurStyle.normal,60*k);
      canvas.drawCircle(r[0] as Offset,size.width*.42,paint);
    }
  }
  void _pixels(Canvas canvas,Size size){
    final rnd=math.Random(3);
    const step=26.0;
    for(double x=0;x<size.width;x+=step){
      for(double y=0;y<size.height;y+=step){
        if(rnd.nextDouble()<.10*k){
          final col=[cPink,cPurple,cWhite][rnd.nextInt(3)];
          canvas.drawRect(Rect.fromLTWH(x+3,y+3,step-8,step-8),Paint()..color=col.withOpacity(.10+.14*rnd.nextDouble()));
        }
      }
    }
  }
  void _bubbles(Canvas canvas,Size size){
    final rnd=math.Random(8);
    for(int i=0;i<12;i++){
      final o=Offset(size.width*rnd.nextDouble(),size.height*rnd.nextDouble());
      final r=10+rnd.nextDouble()*36;
      final col=i%2==0?cPink:cPurple;
      canvas.drawCircle(o,r,Paint()..style=PaintingStyle.stroke..strokeWidth=1.1..color=col.withOpacity(.20*k));
      canvas.drawCircle(o.translate(-r*.3,-r*.3),r*.28,Paint()..color=cWhite.withOpacity(.10*k));
    }
  }
  void _y2k(Canvas canvas,Size size){
    _grid(canvas,size,op:.07,step:34);
    final c=Offset(size.width*.68,size.height*.24);
    canvas.drawCircle(c,64,Paint()..style=PaintingStyle.stroke..strokeWidth=1.4..shader=LinearGradient(colors:[cWhite.withOpacity(.30*k),cPink.withOpacity(.28*k)]).createShader(Rect.fromCircle(center:c,radius:64)));
    _star4(canvas,c,20,cWhite,.30*k);
  }
  @override bool shouldRepaint(covariant _EffectPainter oldDelegate)=>oldDelegate.effect!=effect||oldDelegate.intensity!=intensity||oldDelegate.dark!=dark;
}
class Contacts extends StatefulWidget{
  final ValueChanged<UserX> onOpen;const Contacts({super.key,required this.onOpen});@override State<Contacts> createState()=>_ContactsState();
}
class _ContactsState extends State<Contacts>{
  String q='';bool loading=true;List<UserX> people=[];String? error;
  @override void initState(){super.initState();search();}
  Future<void> search()async{
    if(!mounted)return;setState(()=>loading=true);
    try{
      final a=await Api.get('/users?q='+Uri.encodeQueryComponent(q));
      people=(a as List).map((x)=>UserX((x['id']??'').toString(),(x['display_name']??'User').toString(),(x['username']??'').toString())).toList();
    }catch(e){people=[];error=e.toString();}
    if(mounted)setState(()=>loading=false);
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,18,20,12),child:Row(children:[Text(s.people,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900,letterSpacing:-.7)),const Spacer(),IconButton(tooltip:s.refresh,onPressed:search,icon:const Icon(Icons.refresh_rounded))])),
      Padding(
        padding:const EdgeInsets.fromLTRB(20,0,20,2),
        child:_GlassSearchField(hint:s.findPeopleHint,onChanged:(v){q=v.trim();search();}),
      ),
      const SizedBox(height:10),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):error!=null?ListView(children:[const SizedBox(height:120),EmptyState(icon:Icons.cloud_off_rounded,title:s.connectionError,sub:error!)]):people.isEmpty?ListView(children:[const SizedBox(height:140),EmptyState(icon:Icons.person_search_outlined,title:s.noPeople,sub:s.noPeopleSub)]):ListView.separated(
        padding:const EdgeInsets.fromLTRB(12,3,12,24),itemCount:people.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
        itemBuilder:(_,i){final u=people[i];return _EntryAnimation(delay:Duration(milliseconds:i>7?320:i*45),child:Material(
          type:MaterialType.transparency,
          child:InkWell(
            borderRadius:BorderRadius.circular(22),
            splashColor:pink.withOpacity(.06),
            highlightColor:pink.withOpacity(.035),
            onTap:()=>widget.onOpen(u),
            child:Container(
              padding:const EdgeInsets.symmetric(horizontal:6,vertical:10),
              decoration:BoxDecoration(
                borderRadius:BorderRadius.circular(22),
                border:Border(bottom:BorderSide(color:stroke.withOpacity(.52),width:.7)),
              ),
              child:Row(children:[
                Avatar(name:u.name,size:52),const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(u.name,style:const TextStyle(fontWeight:FontWeight.w800)),
                  const SizedBox(height:3),
                  Text('@'+u.username,style:const TextStyle(color:muted))
                ])),
                const Icon(Icons.arrow_forward_ios_rounded,size:15,color:muted),
              ]),
            ),
          ),
        ));},
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

class _SettingsItem extends StatelessWidget{
  final Widget child;
  final VoidCallback? onTap;
  const _SettingsItem({required this.child,this.onTap});
  @override Widget build(BuildContext context)=>Material(
    type:MaterialType.transparency,
    child:InkWell(
      onTap:onTap,
      borderRadius:BorderRadius.circular(20),
      splashColor:pink.withOpacity(.06),
      highlightColor:pink.withOpacity(.035),
      child:child,
    ),
  );
}

class Settings extends StatelessWidget{
  final String name,username,language;final bool light,notifications;
  final ValueChanged<bool> onTheme,onNotifications;final ValueChanged<String> onLanguage;
  final Future<void> Function(String,String) onProfile;final VoidCallback onLogout;
  const Settings({super.key,required this.name,required this.username,required this.light,required this.language,required this.notifications,required this.onTheme,required this.onLanguage,required this.onNotifications,required this.onProfile,required this.onLogout});
  @override Widget build(BuildContext context){
    final s=S(context);
    return ListView(
      keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
      padding:const EdgeInsets.fromLTRB(18,16,18,110),
      children:[
      const _VibeWordmark(fontSize:28),const SizedBox(height:18),
      _SettingsItem(
        onTap:()=>edit(context),
        child:Padding(
          padding:const EdgeInsets.symmetric(horizontal:4,vertical:10),
          child:Row(children:[
            Avatar(name:name,size:62),const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(name,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
              const SizedBox(height:3),
              Text('@'+username,style:const TextStyle(color:muted))
            ])),
            const Icon(Icons.arrow_forward_ios_rounded,size:16,color:muted),
          ]),
        ),
      ),
      const SizedBox(height:6),
      SwitchListTile(
        contentPadding:const EdgeInsets.symmetric(horizontal:4),
        value:!light,
        onChanged:(v)=>onTheme(!v),
        secondary:const Icon(Icons.nights_stay_outlined),
        title:Text(s.darkY2K,style:const TextStyle(fontWeight:FontWeight.w800)),
        subtitle:Text(s.darkY2KSub,style:const TextStyle(color:muted)),
      ),
      const SizedBox(height:6),
      SwitchListTile(
        contentPadding:const EdgeInsets.symmetric(horizontal:4),
        value:notifications,
        onChanged:onNotifications,
        secondary:const Icon(Icons.notifications_none_rounded),
        title:Text(s.notifications,style:const TextStyle(fontWeight:FontWeight.w800)),
        subtitle:Text(notifications?s.notificationsOn:s.notificationsOff,style:const TextStyle(color:muted)),
      ),
      section(context,s.language,[ListTile(leading:const Icon(Icons.translate_rounded),title:Text(s.language),subtitle:Text(language=='ru'?s.russian:s.english,style:const TextStyle(color:muted)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>languagePicker(context))]),
      section(context,s.security,[
        ListTile(leading:const Icon(Icons.lock_outline_rounded),title:Text(s.privacy),subtitle:Text(s.privacySub,style:const TextStyle(color:muted,fontSize:12)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>info(context,s.privacy,s.privacyBody)),
        ListTile(leading:const Icon(Icons.shield_outlined),title:Text(s.security),subtitle:Text(s.securitySub,style:const TextStyle(color:muted,fontSize:12)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>info(context,s.security,s.securityBody)),
      ]),
      section(context,s.about,[ListTile(leading:const Icon(Icons.info_outline_rounded),title:Text(s.about),subtitle:Text(s.version,style:const TextStyle(color:muted)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>info(context,'vibe<3',s.aboutBody))]),
      const SizedBox(height:18),
      OutlinedButton.icon(onPressed:onLogout,icon:const Icon(Icons.logout_rounded),label:Text(s.signOut),style:OutlinedButton.styleFrom(foregroundColor:pink,side:const BorderSide(color:pink),minimumSize:const Size.fromHeight(52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),
    ]);
  }
  Widget section(BuildContext c,String title,List<Widget> children)=>Padding(
    padding:const EdgeInsets.only(top:14),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Padding(
          padding:const EdgeInsets.only(left:4,bottom:7),
          child:Text(title.toUpperCase(),style:const TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.2)),
        ),
        Material(
          type:MaterialType.transparency,
          child:Column(children:children),
        ),
      ],
    ),
  );
  void languagePicker(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,8,20,4),child:Text(s.chooseLanguage,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900))),
      ListTile(leading:const Text('🇷🇺',style:TextStyle(fontSize:24)),title:Text(s.russian),trailing:language=='ru'?const Icon(Icons.check_rounded,color:pink):null,onTap:(){Navigator.pop(context);onLanguage('ru');}),
      ListTile(leading:const Text('🇺🇸',style:TextStyle(fontSize:24)),title:Text(s.english),trailing:language=='en'?const Icon(Icons.check_rounded,color:pink):null,onTap:(){Navigator.pop(context);onLanguage('en');}),
      const SizedBox(height:12),
    ])));
  }
  void edit(BuildContext context){
    final s=S(context);final n=TextEditingController(text:name);final u=TextEditingController(text:username);bool busy=false;
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
      title:Text(s.editProfile),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        _BareField(controller:n,hint:s.name),
        const SizedBox(height:11),
        Row(children:[const Text('@',style:TextStyle(color:muted,fontSize:16)),const SizedBox(width:2),Expanded(child:_BareField(controller:u,hint:s.username))]),
        const SizedBox(height:7),
        Align(alignment:Alignment.centerLeft,child:Text(s.usernameRules,style:const TextStyle(color:muted,fontSize:11)))
      ]),
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

class CallPage extends StatefulWidget{
  final String name;final bool video;const CallPage({super.key,required this.name,required this.video});
  @override State<CallPage> createState()=>_CallPageState();
}
class _CallPageState extends State<CallPage> with SingleTickerProviderStateMixin{
  late final AnimationController orbit;
  late final Timer timer;int seconds=0;
  @override void initState(){
    super.initState();
    orbit=AnimationController(vsync:this,duration:const Duration(seconds:7))..repeat();
    timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>seconds++);});
  }
  @override void dispose(){orbit.dispose();timer.cancel();super.dispose();}
  String get clock=>'${(seconds~/60).toString().padLeft(2,'0')}:${(seconds%60).toString().padLeft(2,'0')}';
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(
      backgroundColor:bg,
      body:Stack(children:[
        Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[bg,const Color(0xFF17111F),bg])))),
        const Positioned(top:-130,right:-90,child:_Glow(size:300,color:Color(0x2E9B6BFF))),
        const Positioned(bottom:-150,left:-110,child:_Glow(size:320,color:Color(0x2BE76BD0))),
        SafeArea(child:Column(children:[
          const SizedBox(height:26),
          Text(widget.name,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,letterSpacing:-.5)),
          const SizedBox(height:5),
          Text(clock,style:const TextStyle(color:muted,fontSize:15,fontWeight:FontWeight.w700,letterSpacing:2)),
          const SizedBox(height:8),
          Text(widget.video?s.videoCall:s.voiceCall+' · '+s.callConnect,style:const TextStyle(color:muted,fontSize:12)),
          Expanded(
            child:Center(
              child:AnimatedBuilder(
                animation:orbit,
                builder:(context,_)=>SizedBox(
                  width:260,height:260,
                  child:Stack(alignment:Alignment.center,children:[
                    CustomPaint(size:const Size(260,260),painter:_OrbitPainter(t:orbit.value)),
                    Avatar(name:widget.name,size:150),
                  ]),
                ),
              ),
            ),
          ),
          Padding(
            padding:const EdgeInsets.fromLTRB(24,0,24,10),
            child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
              _CallButton(icon:Icons.volume_up_rounded,label:s.ru?'динамик':'speaker',onTap:(){}),
              _CallButton(icon:widget.video?Icons.videocam_off_rounded:Icons.videocam_rounded,label:s.ru?'видео':'video',onTap:(){}),
              _CallButton(icon:Icons.mic_off_rounded,label:s.ru?'выкл. звук':'mute',onTap:(){}),
            ]),
          ),
          Padding(
            padding:const EdgeInsets.fromLTRB(24,4,24,26),
            child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
              _CallButton(icon:Icons.add_rounded,label:s.ru?'добавить':'add',onTap:(){}),
              Container(
                width:76,height:76,
                decoration:BoxDecoration(
                  gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),
                  shape:BoxShape.circle,
                  boxShadow:[BoxShadow(color:pink.withOpacity(.45),blurRadius:26,offset:const Offset(0,8))],
                ),
                child:Material(color:Colors.transparent,child:InkWell(
                  customBorder:const CircleBorder(),
                  onTap:()=>Navigator.pop(context),
                  child:const Center(child:Icon(Icons.call_end_rounded,color:Colors.white,size:32)),
                )),
              ),
              _CallButton(icon:Icons.more_horiz_rounded,label:s.ru?'ещё':'more',onTap:(){}),
            ]),
          ),
        ])),
      ]),
    );
  }
}

class _CallButton extends StatelessWidget{
  final IconData icon;final String label;final VoidCallback onTap;
  const _CallButton({required this.icon,required this.label,required this.onTap});
  @override Widget build(BuildContext context){
    return Column(mainAxisSize:MainAxisSize.min,children:[
      Container(
        width:62,height:62,
        decoration:BoxDecoration(color:surface2.withOpacity(.85),shape:BoxShape.circle,border:Border.all(color:stroke)),
        child:Material(color:Colors.transparent,child:InkWell(customBorder:const CircleBorder(),onTap:onTap,child:Center(child:Icon(icon,color:Colors.white,size:24)))),
      ),
      const SizedBox(height:7),
      Text(label,style:const TextStyle(color:muted,fontSize:10.5,fontWeight:FontWeight.w700)),
    ]);
  }
}

class _OrbitPainter extends CustomPainter{
  final double t;
  _OrbitPainter({required this.t});
  @override void paint(Canvas canvas,Size size){
    final c=Offset(size.width/2,size.height/2);
    canvas.drawCircle(c,118,Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withOpacity(.10));
    final rect=Rect.fromCircle(center:c,radius:118);
    final arc=Paint()
      ..style=PaintingStyle.stroke..strokeWidth=2..strokeCap=StrokeCap.round
      ..shader=SweepGradient(colors:[pink,purple,Colors.transparent],transform:GradientRotation(2*math.pi*t)).createShader(rect);
    canvas.drawArc(rect,0,math.pi*1.35,false,arc);
    final starAngle=2*math.pi*t;
    final starC=c+Offset(math.cos(starAngle)*118,math.sin(starAngle)*118);
    final path=Path()
      ..moveTo(starC.dx,starC.dy-7)
      ..quadraticBezierTo(starC.dx,starC.dy,starC.dx+7,starC.dy)
      ..quadraticBezierTo(starC.dx,starC.dy,starC.dx,starC.dy+7)
      ..quadraticBezierTo(starC.dx,starC.dy,starC.dx-7,starC.dy)
      ..quadraticBezierTo(starC.dx,starC.dy,starC.dx,starC.dy-7)
      ..close();
    canvas.drawPath(path,Paint()..color=pink..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
  }
  @override bool shouldRepaint(covariant _OrbitPainter oldDelegate)=>oldDelegate.t!=t;
}

class VibeSplash extends StatefulWidget{
  const VibeSplash({super.key});
  @override State<VibeSplash> createState()=>_VibeSplashState();
}
class _VibeSplashState extends State<VibeSplash> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  late final Animation<double> reveal;
  @override void initState(){
    super.initState();
    controller=AnimationController(vsync:this,duration:const Duration(milliseconds:1050))..forward();
    reveal=CurvedAnimation(parent:controller,curve:Curves.easeOutCubic);
  }
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:bg,
    body:Stack(children:[
      const Positioned.fill(child:VibeAnimatedBackground()),
      Center(child:AnimatedBuilder(
        animation:reveal,
        builder:(_,__)=>Opacity(
          opacity:reveal.value,
          child:Transform.scale(
            scale:.90+(.10*reveal.value),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              const _BrandMark(),
              const SizedBox(height:20),
              const _VibeWordmark(fontSize:30),
              const SizedBox(height:6),
              const Text('private. personal. yours.',style:TextStyle(color:muted,fontSize:12,fontWeight:FontWeight.w600)),
              const SizedBox(height:26),
              SizedBox(width:92,height:3,child:ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:reveal.value,minHeight:3,backgroundColor:stroke))),
            ]),
          ),
        ),
      )),
    ]),
  );
}

class VibeAnimatedBackground extends StatefulWidget{
  const VibeAnimatedBackground({super.key});
  @override State<VibeAnimatedBackground> createState()=>_VibeAnimatedBackgroundState();
}
class _VibeAnimatedBackgroundState extends State<VibeAnimatedBackground> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  @override void initState(){
    super.initState();
    controller=AnimationController(vsync:this,duration:const Duration(seconds:8))..repeat(reverse:true);
  }
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>IgnorePointer(
    child:AnimatedBuilder(
      animation:controller,
      builder:(_,__) {
        final t=Curves.easeInOut.transform(controller.value);
        return Stack(clipBehavior:Clip.none,children:[
          Positioned(left:-90+(100*t),top:-130+(45*t),child:_Glow(size:300,color:purple.withOpacity(.11))),
          Positioned(right:-100+(65*(1-t)),top:110-(35*t),child:_Glow(size:240,color:pink.withOpacity(.085))),
          Positioned(left:80-(70*t),bottom:-145+(55*t),child:_Glow(size:270,color:blue.withOpacity(.055))),
        ]);
      },
    ),
  );
}

class _EntryAnimation extends StatefulWidget{
  final Widget child;final Duration delay;
  const _EntryAnimation({required this.child,required this.delay});
  @override State<_EntryAnimation> createState()=>_EntryAnimationState();
}
class _EntryAnimationState extends State<_EntryAnimation> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  @override void initState(){
    super.initState();
    controller=AnimationController(vsync:this,duration:const Duration(milliseconds:320));
    Future.delayed(widget.delay,(){if(mounted)controller.forward();});
  }
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>FadeTransition(
    opacity:CurvedAnimation(parent:controller,curve:Curves.easeOutCubic),
    child:SlideTransition(
      position:Tween<Offset>(begin:const Offset(0,.035),end:Offset.zero).animate(CurvedAnimation(parent:controller,curve:Curves.easeOutCubic)),
      child:widget.child,
    ),
  );
}

class EmptyState extends StatelessWidget{
  final IconData icon;final String title,sub;const EmptyState({super.key,required this.icon,required this.title,required this.sub});
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:88,height:88,decoration:BoxDecoration(shape:BoxShape.circle,color:pink.withOpacity(.10),border:Border.all(color:pink.withOpacity(.20))),child:Icon(icon,size:42,color:pink)),
    const SizedBox(height:18),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:7),Text(sub,textAlign:TextAlign.center,style:const TextStyle(color:muted,fontSize:13,height:1.45)),
  ])));
}

class _BrandMark extends StatelessWidget{
  const _BrandMark();
  @override Widget build(BuildContext context)=>Container(width:96,height:96,alignment:Alignment.center,decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),boxShadow:[BoxShadow(color:pink.withOpacity(.55),blurRadius:34,spreadRadius:-10)]),child:const Text('v<3',style:TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.w900,letterSpacing:-1.5)));
}

class _VibeWordmark extends StatelessWidget{
  final double fontSize;
  const _VibeWordmark({this.fontSize=28});
  @override Widget build(BuildContext context)=>ShaderMask(
    shaderCallback:(bounds)=>const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad).createShader(bounds),
    child:Text('vibe<3',style:TextStyle(fontSize:fontSize,fontWeight:FontWeight.w900,letterSpacing:-fontSize*.04,color:Colors.white)),
  );
}

class _Glow extends StatelessWidget{
  final double size;final Color color;const _Glow({required this.size,required this.color});
  @override Widget build(BuildContext context)=>IgnorePointer(child:Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle,color:color,boxShadow:[BoxShadow(color:color,blurRadius:90,spreadRadius:30)])));
}

class _SquareAction extends StatelessWidget{
  final IconData icon;final VoidCallback onTap;final bool gradient,busy;final double size;
  const _SquareAction({required this.icon,required this.onTap,this.gradient=false,this.busy=false,this.size=50});
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Material(
      color:Colors.transparent,
      child:InkWell(
        onTap:busy?null:onTap,
        borderRadius:BorderRadius.circular(size*.36),
        child:Ink(
          width:size,height:size,
          decoration:BoxDecoration(
            gradient:gradient?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad):null,
            color:gradient?null:(dark?surface2:const Color(0xFFECEAF2)),
            borderRadius:BorderRadius.circular(size*.36),
            border:gradient?Border.all(color:Colors.white.withOpacity(.12)):Border.all(color:dark?stroke:Colors.black12),
            boxShadow:gradient?[BoxShadow(color:pink.withOpacity(.30),blurRadius:16,offset:const Offset(0,5))]:null,
          ),
          child:Center(
            child:busy
              ?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
              :Icon(icon,color:gradient?Colors.white:(dark?Colors.white:null),size:size*.44),
          ),
        ),
      ),
    );
  }
}
