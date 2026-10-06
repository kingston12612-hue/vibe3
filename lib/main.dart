import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String get photoVideo=>ru?'Фото / видео':'Photo / video';
  String get voiceMessage=>ru?'Голосовое сообщение':'Voice message';
  String get recording=>ru?'Идёт запись...':'Recording...';
  String get stopAndSend=>ru?'Остановить и отправить':'Stop and send';
  String get cancelRecording=>ru?'Отменить запись':'Cancel recording';
  String get mediaTooLarge=>ru?'Файл слишком большой (максимум 7 МБ).':'File is too large (7 MB maximum).';
  String get mediaFailed=>ru?'Не удалось отправить медиа':'Could not send media';
}

AppStrings S(BuildContext c)=>AppStrings(Localizations.localeOf(c).languageCode=='ru');

ThemeData vibeTheme(bool dark){
  final pageBg=dark?bg:const Color(0xFFF6F4FB);
  final cs=ColorScheme.fromSeed(
    seedColor:purple,
    brightness:dark?Brightness.dark:Brightness.light,
  ).copyWith(
    surface:pageBg,
    surfaceDim:dark?const Color(0xFF07070C):const Color(0xFFE9E7EE),
    surfaceBright:dark?surface2:Colors.white,
    surfaceContainerLowest:pageBg,
    surfaceContainerLow:dark?const Color(0xFF0F0F15):const Color(0xFFF1EFF6),
    surfaceContainer:dark?surface:pageBg,
    surfaceContainerHigh:dark?surface2:const Color(0xFFECEAF2),
    surfaceContainerHighest:dark?const Color(0xFF22222D):const Color(0xFFE4E2E9),
    surfaceVariant:dark?surface2:const Color(0xFFE6E3EA),
    onSurface:dark?const Color(0xFFF4F4FF):const Color(0xFF1B1B22),
    onSurfaceVariant:dark?muted:const Color(0xFF666675),
  );
  return ThemeData(
    useMaterial3:true,
    brightness:dark?Brightness.dark:Brightness.light,
    colorScheme:cs,
    scaffoldBackgroundColor:pageBg,
    canvasColor:pageBg,
    cardTheme:CardTheme(
      color:dark?surface:Colors.white,
      elevation:0,
      margin:EdgeInsets.zero,
      surfaceTintColor:Colors.transparent,
      shadowColor:Colors.transparent,
      shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(22),
        side:BorderSide(color:dark?stroke:Colors.black12),
      ),
    ),
    appBarTheme:AppBarTheme(
      backgroundColor:pageBg,
      foregroundColor:cs.onSurface,
      elevation:0,
      scrolledUnderElevation:0,
      surfaceTintColor:Colors.transparent,
    ),
    bottomSheetTheme:BottomSheetThemeData(
      backgroundColor:dark?surface:Colors.white,
      surfaceTintColor:Colors.transparent,
      modalBackgroundColor:dark?surface:Colors.white,
      elevation:0,
      showDragHandle:true,
    ),
    dialogTheme:DialogTheme(
      backgroundColor:dark?surface:Colors.white,
      surfaceTintColor:Colors.transparent,
      elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
    ),
    popupMenuTheme:PopupMenuThemeData(
      color:dark?surface:Colors.white,
      surfaceTintColor:Colors.transparent,
      elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
    ),
    navigationBarTheme:NavigationBarThemeData(
      backgroundColor:dark?const Color(0xFF0D0D13):Colors.white,
      indicatorColor:purple.withOpacity(.18),
      height:72,
      labelTextStyle:WidgetStatePropertyAll(
        const TextStyle(fontSize:11,fontWeight:FontWeight.w800),
      ),
    ),
    listTileTheme:ListTileThemeData(
      tileColor:Colors.transparent,
      selectedTileColor:purple.withOpacity(.10),
    ),
    inputDecorationTheme:InputDecorationTheme(
      filled:false,
      fillColor:Colors.transparent,
      hoverColor:Colors.transparent,
      hintStyle:TextStyle(color:dark?muted:const Color(0xFF7E7E8E)),
      border:InputBorder.none,
      enabledBorder:InputBorder.none,
      focusedBorder:InputBorder.none,
      disabledBorder:InputBorder.none,
      errorBorder:InputBorder.none,
      focusedErrorBorder:InputBorder.none,
      contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
    ),
    filledButtonTheme:FilledButtonThemeData(
      style:FilledButton.styleFrom(
        backgroundColor:purple,
        foregroundColor:Colors.white,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
        minimumSize:const Size.fromHeight(52),
      ),
    ),
    snackBarTheme:SnackBarThemeData(
      behavior:SnackBarBehavior.floating,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
    ),
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
      systemNavigationBarColor:Colors.transparent,
      systemNavigationBarIconBrightness:Brightness.light,
      systemNavigationBarDividerColor:Colors.transparent,
      systemNavigationBarContrastEnforced:false,
    ));
  }
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
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children:[
            Positioned(top:-120,right:-90,child:_Glow(size:300,color:purple.withOpacity(.20))),
            Positioned(bottom:-140,left:-110,child:_Glow(size:320,color:pink.withOpacity(.14))),
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
                              Text('vibe<3',style:TextStyle(fontSize:27,fontWeight:FontWeight.w900,letterSpacing:-1.2)),
                              SizedBox(height:2),
                              Text('private. personal. yours.',style:TextStyle(color:muted,fontSize:12,fontWeight:FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height:42),
                      Text(
                        register?s.createAccount:s.welcomeBack,
                        style:const TextStyle(fontSize:36,fontWeight:FontWeight.w900,letterSpacing:-1.2,height:1.05),
                      ),
                      const SizedBox(height:9),
                      Text(
                        register?s.joinVibe:s.signInContinue,
                        style:const TextStyle(color:muted,fontSize:14,height:1.45),
                      ),
                      const SizedBox(height:26),
                      Row(
                        children:[
                          _AuthMode(
                            label:s.signIn,
                            active:!register,
                            onTap:busy?null:()=>setState(()=>register=false),
                          ),
                          const SizedBox(width:10),
                          _AuthMode(
                            label:s.createAccount,
                            active:register,
                            onTap:busy?null:()=>setState(()=>register=true),
                          ),
                        ],
                      ),
                      const SizedBox(height:20),
                      AnimatedSwitcher(
                        duration:const Duration(milliseconds:280),
                        switchInCurve:Curves.easeOutCubic,
                        switchOutCurve:Curves.easeInCubic,
                        transitionBuilder:(child,animation)=>FadeTransition(
                          opacity:animation,
                          child:SlideTransition(
                            position:Tween<Offset>(begin:const Offset(0,.035),end:Offset.zero).animate(animation),
                            child:child,
                          ),
                        ),
                        child:register
                          ?Column(
                              key:const ValueKey('register-fields'),
                              children:[
                                _AuthField(controller:name,icon:Icons.person_outline_rounded,hint:s.nameHint,textCapitalization:TextCapitalization.words),
                                const SizedBox(height:11),
                                _AuthField(controller:username,icon:Icons.alternate_email_rounded,hint:s.usernameHint),
                                const SizedBox(height:11),
                              ],
                            )
                          :const SizedBox.shrink(key:ValueKey('login-fields')),
                      ),
                      _AuthField(
                        controller:email,
                        icon:Icons.mail_outline_rounded,
                        hint:s.email,
                        keyboardType:TextInputType.emailAddress,
                      ),
                      const SizedBox(height:11),
                      _AuthField(
                        controller:pass,
                        icon:Icons.lock_outline_rounded,
                        hint:s.password,
                        obscureText:!show1,
                        suffix:IconButton(
                          onPressed:busy?null:()=>setState(()=>show1=!show1),
                          icon:Icon(show1?Icons.visibility_off_outlined:Icons.visibility_outlined),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration:const Duration(milliseconds:260),
                        switchInCurve:Curves.easeOutCubic,
                        switchOutCurve:Curves.easeInCubic,
                        transitionBuilder:(child,animation)=>FadeTransition(
                          opacity:animation,
                          child:SizeTransition(sizeFactor:animation,axisAlignment:-1,child:child),
                        ),
                        child:register
                          ?Padding(
                              key:const ValueKey('repeat-password'),
                              padding:const EdgeInsets.only(top:11),
                              child:_AuthField(
                                controller:pass2,
                                icon:Icons.lock_reset_outlined,
                                hint:s.repeatPassword,                                obscureText:!show2,
                                suffix:IconButton(
                                  onPressed:busy?null:()=>setState(()=>show2=!show2),
                                  icon:Icon(show2?Icons.visibility_off_outlined:Icons.visibility_outlined),
                                ),
                              ),
                            )
                          :const SizedBox.shrink(key:ValueKey('no-repeat-password')),
                      ),
                      const SizedBox(height:18),
                      SizedBox(
                        width:double.infinity,
                        height:56,
                        child:DecoratedBox(
                          decoration:BoxDecoration(
                            gradient:const LinearGradient(
                              begin:Alignment.topLeft,
                              end:Alignment.bottomRight,
                              colors:[purple,pink],
                            ),
                            borderRadius:BorderRadius.circular(17),
                            border:Border.all(color:Colors.white.withOpacity(.10)),
                            boxShadow:[
                              BoxShadow(
                                color:purple.withOpacity(.20),
                                blurRadius:22,
                                offset:const Offset(0,9),
                              ),
                            ],
                          ),
                          child:Material(
                            color:Colors.transparent,
                            child:InkWell(
                              onTap:busy?null:submit,
                              borderRadius:BorderRadius.circular(17),
                              child:Center(
                                child:AnimatedSwitcher(
                                  duration:const Duration(milliseconds:180),
                                  child:busy
                                    ?const SizedBox(
                                        key:ValueKey('busy'),
                                        width:18,height:18,
                                        child:CircularProgressIndicator(strokeWidth:2,color:Colors.white),
                                      )
                                    :Row(
                                        key:ValueKey('ready'),
                                        mainAxisSize:MainAxisSize.min,
                                        children:[
                                          Icon(register?Icons.arrow_forward_rounded:Icons.login_rounded,size:19,color:Colors.white),
                                          const SizedBox(width:9),
                                          Text(
                                            register?s.createAccount:s.signIn,
                                            style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15,color:Colors.white),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height:16),
                      Row(
                        mainAxisAlignment:MainAxisAlignment.center,
                        children:[
                          Icon(Icons.lock_outline_rounded,size:13,color:(dark?muted:Colors.black45)),
                          const SizedBox(width:6),
                          Text(
                            register?s.securitySub:s.securitySub,
                            textAlign:TextAlign.center,
                            style:const TextStyle(color:muted,fontSize:11.5,height:1.3),
                          ),
                        ],
                      ),
                      const SizedBox(height:28),
                      Center(
                        child:TextButton(
                          onPressed:busy?null:()=>setState(()=>register=!register),
                          child:Text(
                            register?s.alreadyHave:s.newToVibe,
                            style:const TextStyle(fontWeight:FontWeight.w800),
                          ),
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
    );
  }
}

class _AuthMode extends StatelessWidget{
  final String label;final bool active;final VoidCallback? onTap;
  const _AuthMode({required this.label,required this.active,required this.onTap});
  @override Widget build(BuildContext context)=>Expanded(
    child:AnimatedContainer(
      duration:const Duration(milliseconds:220),
      curve:Curves.easeOutCubic,
      height:48,
      decoration:BoxDecoration(
        borderRadius:BorderRadius.circular(15),
        gradient:active?const LinearGradient(
          begin:Alignment.topLeft,
          end:Alignment.bottomRight,
          colors:[purple,pink],
        ):null,
        color:active?null:Colors.transparent,
        border:Border.all(color:Colors.transparent),
        boxShadow:active?[BoxShadow(color:purple.withOpacity(.20),blurRadius:18,offset:const Offset(0,6))]:null,
      ),
      child:Material(
        color:Colors.transparent,
        child:InkWell(
          onTap:onTap,
          borderRadius:BorderRadius.circular(15),
          child:Center(
            child:Text(
              label,
              style:TextStyle(
                fontWeight:FontWeight.w900,
                fontSize:13,
                letterSpacing:.1,
                color:active?Colors.white:muted,
              ),
            ),
          ),
        ),
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
  const _AuthField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscureText=false,
    this.suffix,
    this.keyboardType,
    this.textCapitalization=TextCapitalization.none,
  });
  @override State<_AuthField> createState()=>_AuthFieldState();
}

class _AuthFieldState extends State<_AuthField>{
  late final FocusNode focusNode;
  @override void initState(){
    super.initState();
    focusNode=FocusNode();
  }
  @override void dispose(){
    focusNode.dispose();
    super.dispose();
  }
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return SizedBox(
      height:56,
      width:double.infinity,
      child:Row(
        children:[
          const SizedBox(width:16),
          Icon(widget.icon,color:dark?muted:Colors.black54),
          const SizedBox(width:8),
          Expanded(
            child:Stack(
              alignment:Alignment.centerLeft,
              children:[
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable:widget.controller,
                  builder:(context,value,_){
                    if(value.text.isNotEmpty)return const SizedBox.shrink();
                    return IgnorePointer(
                      child:Text(
                        widget.hint,
                        maxLines:1,
                        overflow:TextOverflow.ellipsis,
                        style:const TextStyle(color:muted,fontSize:16),
                      ),
                    );
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
                  cursorColor:purple,
                  backgroundCursorColor:muted,
                  selectionColor:purple.withOpacity(.25),
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
class Msg{final String id,text,sender,type,mediaUrl;final bool mine;Msg(this.id,this.text,this.sender,this.mine,{this.type='text',this.mediaUrl=''} }

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
                  child:SlideTransition(
                    position:Tween<Offset>(
                      begin:const Offset(.018,0),
                      end:Offset.zero,
                    ).animate(CurvedAnimation(
                      parent:animation,
                      curve:Curves.easeOutCubic,
                    )),
                    child:child,
                  ),
                ),
                child:KeyedSubtree(
                  key:ValueKey(tab),
                  child:current,
                ),
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
              boxShadow:[BoxShadow(color:purple.withOpacity(.10),blurRadius:28,spreadRadius:-8,offset:const Offset(0,8))],
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
            color:active?purple.withOpacity(.16):Colors.transparent,
            borderRadius:BorderRadius.circular(19),
            border:active?Border.all(color:purple.withOpacity(.28)):null,
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
    return Stack(
      children:[
        Positioned(top:-170,right:-120,child:_Glow(size:330,color:purple.withOpacity(.12))),
        Positioned(top:100,left:-180,child:_Glow(size:270,color:blue.withOpacity(.045))),
        Positioned(bottom:20,right:-160,child:_Glow(size:290,color:pink.withOpacity(.055))),
        Column(
          children:[
            Padding(
              padding:const EdgeInsets.fromLTRB(22,18,16,8),
              child:Row(
                children:[
                  Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      const Text('vibe<3',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,letterSpacing:-1.3)),
                      const SizedBox(height:2),
                      Text(s.chats.toLowerCase(),style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.w700,letterSpacing:.7)),
                    ],
                  ),
                  const Spacer(),
                  _CircleAction(icon:Icons.search_rounded,onTap:()async{
                    final x=await Navigator.push<Chat?>(context,MaterialPageRoute(builder:(_)=>ChatSearchPage(list:list)));
                    if(x!=null&&mounted)widget.onOpen(x);
                  }),
                  const SizedBox(width:8),
                  _CircleAction(icon:Icons.add_comment_rounded,filled:true,onTap:widget.onNewChat),
                ],
              ),
            ),
            Padding(
              padding:const EdgeInsets.fromLTRB(22,8,22,12),
              child:_GlassSearchField(hint:s.searchChats,onChanged:(v)=>setState(()=>q=v)),
            ),
            Expanded(
              child:RefreshIndicator(
                color:purple,
                backgroundColor:surface,
                onRefresh:load,
                child:loading
                  ?ListView(children:[const SizedBox(height:170),const Center(child:CircularProgressIndicator(color:purple))])
                  :filtered.isEmpty
                    ?ListView(
                      physics:const AlwaysScrollableScrollPhysics(),
                      children:[const SizedBox(height:125),EmptyState(icon:Icons.forum_outlined,title:s.noChats,sub:s.noChatsSub)]
                    )
                    :ListView.separated(
                      physics:const AlwaysScrollableScrollPhysics(),
                      padding:const EdgeInsets.fromLTRB(14,2,14,100),
                      itemCount:filtered.length,
                      separatorBuilder:(_,__)=>const SizedBox(height:9),
                      itemBuilder:(_,i)=>_EntryAnimation(
                        delay:Duration(milliseconds:i>7?320:i*45),
                        child:Tile(chat:filtered[i],tap:()=>widget.onOpen(filtered[i])),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ],
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
    final filtered=widget.list.where((x)=>
      x.name.toLowerCase().contains(q)||
      x.preview.toLowerCase().contains(q)
    ).toList();
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
          child:_BareField(
            controller:controller,
            hint:s.searchChats,
            icon:Icons.search_rounded,
            onChanged:(_)=>setState((){}),
          ),
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
            itemBuilder:(_,i)=>Tile(
              chat:filtered[i],
              tap:()=>Navigator.pop(context,filtered[i]),
            ),
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
                  cursorColor:purple,
                  backgroundCursorColor:muted,
                  selectionColor:purple.withOpacity(.25),
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
  @override Widget build(BuildContext context)=>_BareField(hint:hint,icon:Icons.search_rounded,onChanged:onChanged);
}

class _Y2KGrid extends CustomPainter{
  final Color color;
  _Y2KGrid(this.color);
  @override void paint(Canvas canvas,Size size){
    final p=Paint()..color=color..strokeWidth=.55;
    const step=38.0;
    for(double x=0;x<size.width;x+=step){canvas.drawLine(Offset(x,0),Offset(x,size.height),p);}
    for(double y=0;y<size.height;y+=step){canvas.drawLine(Offset(0,y),Offset(size.width,y),p);}
    final glow=Paint()..color=color.withOpacity(.16)..style=PaintingStyle.fill;
    for(final o in [Offset(size.width*.12,size.height*.18),Offset(size.width*.82,size.height*.28),Offset(size.width*.62,size.height*.78)]){
      canvas.drawCircle(o,2.2,glow);
    }
  }
  @override bool shouldRepaint(covariant _Y2KGrid oldDelegate)=>oldDelegate.color!=color;
}

class Tile extends StatelessWidget{
  final Chat chat;final VoidCallback tap;
  const Tile({super.key,required this.chat,required this.tap});
  @override Widget build(BuildContext context){
    return Material(
      type:MaterialType.transparency,
      child:InkWell(
        onTap:tap,
        borderRadius:BorderRadius.circular(22),
        splashColor:purple.withOpacity(.06),
        highlightColor:purple.withOpacity(.035),
        child:Container(
          padding:const EdgeInsets.symmetric(horizontal:4,vertical:10),
          decoration:BoxDecoration(
            border:Border(bottom:BorderSide(color:stroke.withOpacity(.52),width:.7)),
          ),
          child:Row(
            children:[
              Avatar(name:chat.name,size:56),
              const SizedBox(width:12),
              Expanded(
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(chat.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
                    const SizedBox(height:4),
                    Text(chat.preview.isEmpty?S(context).active:chat.preview,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:13)),
                  ],
                ),
              ),
              const SizedBox(width:8),
              if(chat.time.isNotEmpty)Align(
                alignment:Alignment.topRight,
                child:Text(chat.time,style:const TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.w700)),
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
    return Container(width:size,height:size,alignment:Alignment.center,decoration:BoxDecoration(
        shape:BoxShape.circle,
        gradient:LinearGradient(colors:[colors[i],colors[(i+1)%colors.length]]),
        border:Border.all(color:Colors.white.withOpacity(.16),width:1),
        boxShadow:[BoxShadow(color:colors[i].withOpacity(.24),blurRadius:18,spreadRadius:-2)],
      ),child:Text(name.isEmpty?'?':name[0].toUpperCase(),style:TextStyle(color:Colors.white,fontSize:size*.34,fontWeight:FontWeight.w900)));
  }
}

class ChatPage extends StatefulWidget{
  final Chat chat;const ChatPage({super.key,required this.chat});@override State<ChatPage> createState()=>_ChatState();
}
class _ChatState extends State<ChatPage>{
  final input=TextEditingController();final scroll=ScrollController();List<Msg> msgs=[];
  final recorder=AudioRecorder();
  bool loading=true,sending=false;IO.Socket? socket;String myId='';
  @override void initState(){super.initState();load();}
  @override void dispose(){socket?.disconnect();socket?.dispose();recorder.dispose();input.dispose();scroll.dispose();super.dispose();}
  Future<void> load()async{
    try{
      final me=await Api.get('/me');myId=(me['id']??'').toString();
      final a=await Api.get('/chats/'+widget.chat.id+'/messages');      msgs=(a as List).map((x)=>Msg((x['id']??'').toString(),(x['body']??'').toString(),(x['sender_name']??'').toString(),(x['sender_id']??'').toString()==myId,type:(x['message_type']??'text').toString(),mediaUrl:(x['media_url']??'').toString())).toList();
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
      setState(()=>msgs.add(Msg(id,(data['body']??'').toString(),(data['sender_name']??'').toString(),(data['sender_id']??'').toString()==myId,type:(data['message_type']??'text').toString(),mediaUrl:(data['media_url']??'').toString())));
      WidgetsBinding.instance.addPostFrameCallback((_)=>scrollEnd());
    });
    socket!.connect();
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
      final payload={'chatId':widget.chat.id,'body':body,'type':type,'mediaUrl':mediaUrl};
      if(socket?.connected==true){
        socket!.emit('message',payload);
      }else{
        final x=await Api.post('/chats/'+widget.chat.id+'/messages',{'body':body,'type':type,'mediaUrl':mediaUrl});
        final id=(x['id']??DateTime.now().microsecondsSinceEpoch).toString();
        if(mounted&&!msgs.any((m)=>m.id==id))setState(()=>msgs.add(Msg(id,body,'',true,type:type,mediaUrl:mediaUrl)));
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
        content:const Icon(Icons.mic_rounded,size:56,color:purple),
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
      try{await recorder.cancel();}catch(_){ }
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).mediaFailed)));
    }
  }
  void scrollEnd(){if(!scroll.hasClients)return;scroll.animateTo(scroll.position.maxScrollExtent,duration:const Duration(milliseconds:220),curve:Curves.easeOut);}
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(
      body:Column(children:[
        SafeArea(
          bottom:false,
          child:Container(
            height:72,
            color:bg,
            padding:const EdgeInsets.symmetric(horizontal:6),
            child:Row(
              children:[
                SizedBox(
                  width:48,
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
                            const SizedBox(width:9),
                            Expanded(
                              child:Column(
                                mainAxisAlignment:MainAxisAlignment.center,
                                crossAxisAlignment:CrossAxisAlignment.start,
                                children:[
                                  Text(widget.chat.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
                                  Text(widget.chat.online?s.online:s.active,style:const TextStyle(color:muted,fontSize:11)),
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
                  icon:const Icon(Icons.call_outlined),
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
          child:Stack(
            children:[
              Positioned.fill(child:CustomPaint(painter:_Y2KGrid(stroke.withOpacity(.34)))),
              Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[purple.withOpacity(.045),Colors.transparent,pink.withOpacity(.035)])))),
              loading
                ?const Center(child:CircularProgressIndicator())
                :msgs.isEmpty
                  ?EmptyState(icon:Icons.auto_awesome_outlined,title:s.joinVibe,sub:s.noChatsSub)
                  :ListView.builder(controller:scroll,padding:const EdgeInsets.fromLTRB(14,18,14,14),itemCount:msgs.length,itemBuilder:(_,i)=>Bubble(key:ValueKey(msgs[i].id),msg:msgs[i])),
            ],
          ),
        ),
        SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(10,6,10,10),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
          _CircleAction(icon:Icons.add_rounded,onTap:()=>showAttachments(context)),const SizedBox(width:8),
          Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:0,vertical:1),child:_BareField(controller:input,hint:s.messageHint,maxLines:5))),
          const SizedBox(width:8),_CircleAction(icon:Icons.arrow_upward_rounded,filled:true,busy:sending,onTap:send),
        ]))),
      ]),
    );
  }
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
              ListTile(
                leading:const Icon(Icons.person_outline_rounded),
                title:Text(s.profile),
                subtitle:Text(s.editProfile,style:const TextStyle(color:muted)),
                onTap:(){
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context:context,
                    showDragHandle:true,
                    builder:(_)=>SafeArea(
                      child:Padding(
                        padding:const EdgeInsets.fromLTRB(20,8,20,28),
                        child:Column(
                          mainAxisSize:MainAxisSize.min,
                          children:[
                            Avatar(name:widget.chat.name,size:96),
                            const SizedBox(height:14),
                            Text(widget.chat.name,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
                            if(username.isNotEmpty) ...[
                              const SizedBox(height:5),
                              Text('@'+username,style:const TextStyle(color:muted,fontSize:15)),
                            ],
                            const SizedBox(height:18),
                            Row(
                              mainAxisAlignment:MainAxisAlignment.center,
                              children:[
                                OutlinedButton.icon(onPressed:()=>openCall(context,false),icon:const Icon(Icons.call_outlined),label:Text(s.voiceCall)),
                                const SizedBox(width:10),
                                OutlinedButton.icon(onPressed:()=>openCall(context,true),icon:const Icon(Icons.videocam_outlined),label:Text(s.videoCall)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              ListTile(leading:const Icon(Icons.call_outlined),title:Text(s.voiceCall),onTap:(){Navigator.pop(context);openCall(context,false);}),
              ListTile(leading:const Icon(Icons.videocam_outlined),title:Text(s.videoCall),onTap:(){Navigator.pop(context);openCall(context,true);}),
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
      ListTile(leading:const Icon(Icons.refresh_rounded),title:Text(s.refresh),onTap:(){Navigator.pop(context);setState(()=>loading=true);load();}),
      const SizedBox(height:10),
    ])));
  }
  void showAttachments(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.photo_library_outlined),title:Text(s.photoVideo),onTap:(){Navigator.pop(context);pickMedia();}),
      ListTile(leading:const Icon(Icons.mic_none_rounded),title:Text(s.voiceMessage),onTap:(){Navigator.pop(context);recordVoice();}),
      const SizedBox(height:10),
    ])));
  }
  void openCall(BuildContext context,bool video)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CallPage(name:widget.chat.name,video:video)));
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
    return Align(
      alignment:msg.mine?Alignment.centerRight:Alignment.centerLeft,
      child:FadeTransition(
        opacity:CurvedAnimation(parent:controller,curve:Curves.easeOut),
        child:ScaleTransition(
          scale:scale,
          child:Container(
            constraints:const BoxConstraints(maxWidth:325),margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:15,vertical:11),
            decoration:BoxDecoration(gradient:msg.mine?const LinearGradient(colors:[purple,pink]):null,color:msg.mine?null:(dark?surface2:Colors.white),borderRadius:BorderRadius.only(topLeft:const Radius.circular(18),topRight:const Radius.circular(18),bottomLeft:Radius.circular(msg.mine?18:5),bottomRight:Radius.circular(msg.mine?5:18)),border:msg.mine?null:Border.all(color:dark?stroke:Colors.black12)),
            child:msg.type=='image'&&msg.mediaUrl.isNotEmpty
              ?ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(msg.mediaUrl.substring(msg.mediaUrl.indexOf(',')+1)),width:230,height:230,fit:BoxFit.cover))
              :Row(mainAxisSize:MainAxisSize.min,children:[
                  if(msg.type=='video')const Icon(Icons.videocam_rounded,size:22,color:Colors.white),
                  if(msg.type=='audio')const Icon(Icons.mic_rounded,size:22,color:Colors.white),
                  if(msg.type!='text')const SizedBox(width:8),
                  Flexible(child:Text(msg.text,style:TextStyle(color:msg.mine?Colors.white:null,fontSize:15,height:1.3))),
                ]),
          ),
        ),
      ),
    );
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
      Padding(
        padding:const EdgeInsets.fromLTRB(20,0,20,2),
        child:_GlassSearchField(hint:s.findPeopleHint,onChanged:(v){q=v.trim();search();}),
      ),
      const SizedBox(height:10),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):people.isEmpty?ListView(children:[const SizedBox(height:140),EmptyState(icon:Icons.person_search_outlined,title:s.noPeople,sub:s.noPeopleSub)]):ListView.separated(
        padding:const EdgeInsets.fromLTRB(12,3,12,24),itemCount:people.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
        itemBuilder:(_,i){final u=people[i];return _EntryAnimation(delay:Duration(milliseconds:i>7?320:i*45),child:Material(
          type:MaterialType.transparency,
          child:InkWell(
            borderRadius:BorderRadius.circular(22),
            splashColor:purple.withOpacity(.06),
            highlightColor:purple.withOpacity(.035),
            onTap:()=>widget.onOpen(u),
            child:Container(
              padding:const EdgeInsets.symmetric(horizontal:4,vertical:10),
              decoration:BoxDecoration(
                border:Border(bottom:BorderSide(color:stroke.withOpacity(.52),width:.7)),
              ),
              child:Row(children:[
                Avatar(name:u.name,size:52),const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(u.name,style:const TextStyle(fontWeight:FontWeight.w800)),
                  const SizedBox(height:3),
                  Text('@'+u.username,style:const TextStyle(color:muted))
                ])),
                const Icon(Icons.arrow_forward_ios_rounded,size:15),
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
      splashColor:purple.withOpacity(.06),
      highlightColor:purple.withOpacity(.035),
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
      const _VibeWordmark(),const SizedBox(height:18),
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
            const Icon(Icons.arrow_forward_ios_rounded,size:16),
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
      OutlinedButton.icon(onPressed:onLogout,icon:const Icon(Icons.logout_rounded),label:Text(s.signOut),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),
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
      ListTile(leading:const Text('🇷🇺',style:TextStyle(fontSize:24)),title:Text(s.russian),trailing:language=='ru'?const Icon(Icons.check_rounded,color:purple):null,onTap:(){Navigator.pop(context);onLanguage('ru');}),
      ListTile(leading:const Text('🇺🇸',style:TextStyle(fontSize:24)),title:Text(s.english),trailing:language=='en'?const Icon(Icons.check_rounded,color:purple):null,onTap:(){Navigator.pop(context);onLanguage('en');}),
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
              const Text('vibe<3',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,letterSpacing:-1.2)),
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
          Positioned(
            left:-90+(100*t),
            top:-130+(45*t),
            child:_Glow(size:300,color:purple.withOpacity(.11)),
          ),
          Positioned(
            right:-100+(65*(1-t)),
            top:110-(35*t),
            child:_Glow(size:240,color:pink.withOpacity(.075)),
          ),
          Positioned(
            left:80-(70*t),
            bottom:-145+(55*t),
            child:_Glow(size:270,color:blue.withOpacity(.055)),
          ),
        ]);
      },
    ),
  );
}

class _EntryAnimation extends StatefulWidget{
  final Widget child;final Duration delay;  const _EntryAnimation({required this.child,required this.delay});
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
      position:Tween<Offset>(begin:const Offset(0,.035),end:Offset.zero).animate(
        CurvedAnimation(parent:controller,curve:Curves.easeOutCubic),
      ),
      child:widget.child,
    ),
  );
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
class _CircleAction extends StatefulWidget{
  final IconData icon;final VoidCallback onTap;final bool filled,busy;
  const _CircleAction({required this.icon,required this.onTap,this.filled=false,this.busy=false});
  @override State<_CircleAction> createState()=>_CircleActionState();
}
class _CircleActionState extends State<_CircleAction>{
  bool pressed=false;
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return GestureDetector(
      onTapDown:(_)=>setState(()=>pressed=true),
      onTapCancel:()=>setState(()=>pressed=false),
      onTapUp:(_)=>setState(()=>pressed=false),
      child:AnimatedScale(
        scale:pressed ? .90 : 1,
        duration:const Duration(milliseconds:90),
        curve:Curves.easeOut,
        child:Material(
          color:widget.filled?purple:(dark?surface2:const Color(0xFFECEAF2)),
          borderRadius:BorderRadius.circular(18),
          child:InkWell(
            borderRadius:BorderRadius.circular(18),
            onTap:widget.busy?null:widget.onTap,
            child:SizedBox(width:50,height:50,child:Center(child:widget.busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):Icon(widget.icon,color:widget.filled?Colors.white:null))),
          ),
        ),
      ),
    );
  }
}