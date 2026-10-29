import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:audioplayers/audioplayers.dart';
import 'callkit.dart';
import 'mediaview.dart';

String apiBase=const String.fromEnvironment('VIBE_API',defaultValue:'https://vibe3-api.onrender.com');
const bg=Color(0xFF0A0A10),surface=Color(0xFF15151D),surface2=Color(0xFF1C1C26),stroke=Color(0xFF282833),green=Color(0xFF59E391);
const muted=Color(0xFF9193A5),purple=Color(0xFF9B6BFF),blue=Color(0xFF6FA8FF),pink=Color(0xFFE76BD0);
const brandGrad=[pink,purple];

// Палитра из ТЕМЫ (не константы!): любые экраны обязаны брать цвета отсюда,
// чтобы светлая тема применялась во всём приложении и текст оставался видимым.
extension VibePal on BuildContext{
  bool get vibDark=>Theme.of(this).brightness==Brightness.dark;
  Color get cBg=>Theme.of(this).scaffoldBackgroundColor;
  Color get cSurf=>Theme.of(this).colorScheme.surface;
  Color get cSurf2=>Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get cLine=>Theme.of(this).colorScheme.outline;
  Color get cMut=>Theme.of(this).colorScheme.onSurfaceVariant;
  Color get cTxt=>Theme.of(this).colorScheme.onSurface;
}

// Глобальное состояние: какой чат открыт (чтобы не показывать баннер в нём),
// версия списка чатов (reload при удалении чужим участником), живые тумблеры приватности
String? activeOpenChatId;
final chatsChanged=ValueNotifier<int>(0);
bool gShowOnline=true,gShowTyping=true,gShowReads=true,gHidePreviews=false;
bool gPinOn=false,gPinBg=false;

// --- Безопасность: запрет скриншотов (FLAG_SECURE) + хэш PIN-кода ---
const _secureCh=MethodChannel('vibe.secure');
Future<void> applySecureFlag(bool on)async{try{await _secureCh.invokeMethod('setSecure',{'on':on});}catch(_){}}
String pinHash(String pin){int h=0xcbf29ce484222325;for(final c in ('vibe<3|'+pin).codeUnits){h=(h^c)&0xFFFFFFFFFFFFFFFF;h=(h*0x100000001b3)&0xFFFFFFFFFFFFFFFF;}return h.toRadixString(16);}

Future<void> main()async{
  WidgetsFlutterBinding.ensureInitialized();
  // Серый экран в релизе = молчаливый краш: ловим всё и показываем/отправляем текст
  FlutterError.onError=(d){FlutterError.presentError(d);Api.debugLog('FLUTTER: ${d.exception} || ${d.stack}');};
  PlatformDispatcher.instance.onError=(e,st){Api.debugLog('UNCAUGHT: $e || $st');return true;};
  ErrorWidget.builder=(d)=>Container(color:const Color(0xFF14141C),alignment:Alignment.center,padding:const EdgeInsets.all(16),child:SingleChildScrollView(child:Text('ОШИБКА ЭКРАНА (пришли скрин разработчику):\n$d',style:const TextStyle(color:Color(0xFFFF6B81),fontSize:12))));
  try{
    final p=await SharedPreferences.getInstance();
    final u=p.getString('server_url');
    if(u!=null&&u.trim().length>8)apiBase=u.trim().replaceAll(RegExp(r'/+$'),'');
    if(p.getBool('secure_mode')??false)await applySecureFlag(true); // запрет скриншотов
  }catch(_){}
  Api.debugLog('app start v1.3.2 api=$apiBase');
  runApp(const VibeApp());
}

class Api{
 static bool _awake=false;
 static Future<String?> token()async=>(await SharedPreferences.getInstance()).getString('token');
 static Future<Map<String,String>> headers()async{final t=await token();return {'Content-Type':'application/json',if(t!=null)'Authorization':'Bearer $t'};}
 static bool _transient(Object e)=>e is TimeoutException||e is SocketException||e is HandshakeException||e is http.ClientException||['timeout','socketexception','clientexception','handshake','oserror','connection refused','connection reset','network is unreachable','failed host lookup'].any((k)=>e.toString().toLowerCase().contains(k));
 static void debugLog(String m){try{http.post(Uri.parse('$apiBase/debug/log'),headers:const{'Content-Type':'application/json'},body:jsonEncode({'msg':m,'v':'1.3.0'})).timeout(const Duration(seconds:5));}catch(_){}}
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
 static Future<dynamic> delete(String path)=>_guard(()async{final r=await http.delete(Uri.parse('$apiBase$path'),headers:await headers()).timeout(const Duration(seconds:60));if(r.statusCode<200||r.statusCode>=300)throw Exception('http_${r.statusCode}');try{return jsonDecode(r.body);}catch(_){return{};}});
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
  String get noMessages=>ru?'Сообщений пока нет':'No messages yet';
  String get noMessagesSub=>ru?'Напиши первым — дойдёт мгновенно.':'Say hi — it arrives instantly.';
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
  String get version=>'v1.3.2';
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
  String get incomingCall=>ru?'Входящий звонок':'Incoming call';
  String get ringing=>ru?'Вызов...':'Ringing...';
  String get connecting=>ru?'Соединение...':'Connecting...';
  String get callEnded=>ru?'Звонок завершён':'Call ended';
  String get declined=>ru?'Отклонено':'Declined';
  String get missedCall=>ru?'Пропущен':'Missed';
  String get accept=>ru?'Принять':'Accept';
  String get decline=>ru?'Отклонить':'Decline';
  String get callFailed=>ru?'Не удалось позвонить':'Could not place the call';
  String get groupOnlyCall=>ru?'Звонки работают в личных чатах':'Calls work in direct chats';
  String get noCalls=>ru?'Звонков пока нет':'No calls yet';
  String get noCallsSub=>ru?'История звонков появится здесь':'Your call history will appear here';
  String get copy=>ru?'Копировать':'Copy';
  String get copied=>ru?'Скопировано':'Copied';
  String get deleteMsg=>ru?'Удалить сообщение':'Delete message';
  String get deleteMsgConfirm=>ru?'Удалить это сообщение?':'Delete this message?';
  String get delete=>ru?'Удалить':'Delete';
  String get deleteChat=>ru?'Удалить чат':'Delete chat';
  String get deleteChatConfirm=>ru?'Удалить чат? У собеседника он останется.':'Delete this chat? Your peer keeps theirs.';
  String get chatDeleted=>ru?'Чат удалён':'Chat deleted';
  String get markRead=>ru?'Отметить прочитанным':'Mark as read';
  String get createGroup=>ru?'Создать группу':'Create group';
  String get groupName=>ru?'Название группы':'Group name';
  String get groupCreated=>ru?'Группа создана':'Group created';
  String get members=>ru?'Участники':'Members';
  String get addMember=>ru?'Добавить участника':'Add member';
  String get memberAdded=>ru?'Участник добавлен':'Member added';
  String get showOnline=>ru?'Показывать «в сети»':'Show online status';
  String get showTyping=>ru?'Показывать «печатает...»':'Show typing indicator';
  String get privacyRealSub=>ru?'Настройки применяются мгновенно и на сервере':'Applies instantly, on the server too';
  String get showReads=>ru?'Отправлять отчёты о прочтении':'Send read receipts';
  String get showReadsSub=>ru?'Собеседник видит галочки прочтения':'Peer sees your read ticks';
  String get hidePreviews=>ru?'Скрывать текст в списке чатов':'Hide message previews';
  String get hidePreviewsSub=>ru?'Вместо текста — «Текст скрыт»':'Previews are replaced';
  String get hiddenPreview=>ru?'Текст скрыт':'Hidden';
  String get appearance=>ru?'Оформление':'Appearance';
  String get themeDark=>ru?'Тёмная':'Dark';
  String get themeLight=>ru?'Светлая':'Light';
  String get themeSub=>ru?'Выбери тему интерфейса':'Pick interface theme';
  String get photoProfile=>ru?'Фото профиля':'Profile photo';
  String get cameraShot=>ru?'Сделать фото':'Take a photo';
  String get fromGallery=>ru?'Выбрать из галереи':'Choose from gallery';
  String get removePhoto=>ru?'Удалить фото':'Remove photo';
  String get photoUpdated=>ru?'Фото профиля обновлено':'Profile photo updated';
  String get saved=>ru?'Сохранено':'Saved';
  String get pinLock=>ru?'PIN-код на приложение':'App PIN code';
  String get pinEnabled=>ru?'Включён':'Enabled';
  String get pinDisabled=>ru?'Выключен':'Disabled';
  String get pinEnable=>ru?'Включить PIN-код':'Enable PIN';
  String get pinChange=>ru?'Изменить PIN':'Change PIN';
  String get pinDisable=>ru?'Выключить PIN-код':'Disable PIN';
  String get pinCreate=>ru?'Придумай PIN-код':'Create a PIN';
  String get pinRepeat=>ru?'Повтори PIN-код':'Repeat the PIN';
  String get pinEnter=>ru?'Введи текущий PIN':'Enter current PIN';
  String get pinUnlock=>ru?'Введи PIN-код':'Enter your PIN';
  String get pinWrong=>ru?'Неверный PIN':'Wrong PIN';
  String get pinMismatch=>ru?'PIN-коды не совпадают':'PINs do not match';
  String get pinBg=>ru?'Блокировать при сворачивании':'Lock when minimized';
  String get pinBgSub=>ru?'Экран PIN при возврате в приложение':'PIN screen on return';
  String get pinSignOut=>ru?'Выйти из аккаунта':'Sign out';
  String get pinSignOutQ=>ru?'Выйти и сбросить вход?':'Sign out of this account?';
  String get lockedTitle=>ru?'Приложение заблокировано':'App locked';
  String get screenshots=>ru?'Запрет скриншотов':'Block screenshots';
  String get screenshotsSub=>ru?'Скрывает содержимое в меню недавних приложений':'Hides content in the recents screen';
  String get securityRealSub=>ru?'PIN-код и защита экрана':'PIN code and screen shield';
  String get securityNote=>ru?'Вход защищён серверной JWT-сессией. PIN-код и запрет скриншотов защищают приложение на самом телефоне.':'Login is protected by a server-side JWT session. The PIN and screenshot shield protect the app on this device.';
  String get photoTooBig=>ru?'Фото слишком большое, попробуй другое':'Photo is too large, try another one';
  String get profileTagline=>ru?'на vibe<3':'on vibe<3';
  String get emailLabel=>'Email';
  String get usernameLabel=>'Username';
  String get openProfile=>ru?'Открыть профиль':'Open profile';
  String get themePick=>ru?'Тема интерфейса':'Interface theme';
  String get themeSystemHint=>ru?'Меняется сразу во всём приложении':'Applies to the whole app instantly';
  String get privacyWhoOnline=>ru?'Кто видит, когда я в сети':"Who sees when I'm online";
  String get privacyEveryone=>ru?'Все':'Everyone';
  String get privacyNobody=>ru?'Никто':'Nobody';
  String get privacyWhoOnlineSub=>ru?'Если «Никто» — твой статус скрыт даже у контактов':'If Nobody, your presence is hidden from everyone';
  String get privacyShotsMine=>ru?'Защита моих чатов от скриншотов':'Screenshot shield for my chats';
  String get privacyShotsMineSub=>ru?'Собеседник не сможет сделать скриншот чата с тобой':'Your peer cannot screenshot the chat with you';
  String get privacyWhoCalls=>ru?'Кто может звонить мне':'Who can call me';
  String get privacyWhoCallsSub=>ru?'Если «Никто» — сервер сразу отклоняет звонки':'If Nobody, the server rejects calls instantly';
  String get privacySectionVisibility=>ru?'Статус и активность':'Presence and activity';
  String get privacySectionChats=>ru?'Чаты и звонки':'Chats and calls';
  String get callsBlockedByPeer=>ru?'Собеседник запретил звонки в приватности':'Peer disabled calls in privacy';
  String get shotsByPeer=>ru?'Скриншоты в этом чате запрещены (просьба собеседника)':'Screenshots are blocked here (peer request)';
  String get secSectionPin=>ru?'PIN-код':'PIN code';
  String get secSectionScreen=>ru?'Экран':'Screen';
  String get secPinSub=>ru?'Второй замок: без PIN приложение не открыть':'A second lock: the app cannot open without it';
  String get secShotsSub2=>ru?'Нельзя сделать скриншот или запись экрана':'Screenshots and screen recording are blocked';
  String get saveChanges=>ru?'Сохранить изменения':'Save changes';
  String get profileUpdated=>ru?'Профиль обновлён':'Profile updated';
  // --- v1.3.0: контакты, чужой профиль, верификация, bio ---
  String get tabContacts=>ru?'Контакты':'Contacts';
  String get tabAllPeople=>ru?'Все люди':'Everyone';
  String get noContacts=>ru?'Пока нет контактов':'No contacts yet';
  String get noContactsSub=>ru?'Открой «Все люди», найди человека и добавь в контакты':'Open Everyone, find a person and add them';
  String get addContact=>ru?'В контакты':'Add contact';
  String get inContacts=>ru?'В контактах':'In contacts';
  String get removeContact=>ru?'Удалить из контактов':'Remove from contacts';
  String get contactAdded=>ru?'Добавлено в контакты':'Added to contacts';
  String get contactRemoved=>ru?'Удалено из контактов':'Removed from contacts';
  String get writeMsg=>ru?'Написать':'Message';
  String get aboutBio=>ru?'О себе':'Bio';
  String get bioHint=>ru?'Пара слов о себе':'A few words about you';
  String get bioEditHint=>ru?'Расскажи о себе':'Tell something about yourself';
  String get phoneLabel=>ru?'Телефон':'Phone';
  String get verifiedBadge=>ru?'подтверждено':'verified';
  String get unverifiedBadge=>ru?'не подтверждено':'not verified';
  String get verifyEmailTitle=>ru?'Подтвердить почту':'Verify email';
  String get verifyPhoneTitle=>ru?'Подтвердить телефон':'Verify phone';
  String get lastSeenRecent=>ru?'был(а) недавно':'last seen recently';
  String get lastSeenLong=>ru?'был(а) давно':'last seen a while ago';
  String get regPhoneTitle=>ru?'Твой номер телефона':'Your phone number';
  String get regPhoneSub=>ru?'По номеру тебя найдут контакты. Пришлём код подтверждения.':'People will find you by it. We will send a confirmation code.';
  String get regPhoneHint=>ru?'+7 900 000-00-00':'+7 900 000-00-00';
  String get regEmailTitle=>ru?'Подтверди почту':'Confirm your email';
  String get regCodeTitle=>ru?'Введи код':'Enter the code';
  String get regCodeSentPhone=>ru?'Код отправлен на номер':'Code sent to';
  String get regCodeSentEmail=>ru?'Код отправлен на':'Code sent to';
  String get regCodeDevNote=>ru?'SMS/почтовый шлюз не подключён — тестовый код ниже. Владелец подключит настоящую доставку ключами.':'No SMS/mail gateway yet — dev code below. Real delivery is coming.';
  String get regCodeResend=>ru?'Отправить код ещё раз':'Send the code again';
  String get regResendIn=>ru?'Отправить ещё раз через':'Resend in';
  String get regVerify=>ru?'Подтвердить':'Verify';
  String get codeInvalid=>ru?'Неверный код':'Wrong code';
  String get codeExpired=>ru?'Код устарел, отправь новый':'Code expired, request a new one';
  String get phoneTaken=>ru?'Этот номер уже занят':'Phone already registered';
  String get emailVerifiedOk=>ru?'Почта подтверждена ✓':'Email verified ✓';
  String get phoneVerifiedOk=>ru?'Телефон подтверждён ✓':'Phone verified ✓';
  String get loginPhoneHint=>ru?'почта, @username или телефон':'email, @username or phone';
  String get secChat=>ru?'Написать':'Message';
  String get joinedDate=>ru?'В vibe<3 с':'On vibe<3 since';
  String get monthsJan=>['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'].join('|');
  String months(int i, bool ru)=>ru?['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'][i]:['January','February','March','April','May','June','July','August','September','October','November','December'][i];
  String get profileTitle=>ru?'Профиль':'Profile';
  String get addPhone=>ru?'Добавить номер телефона':'Add phone number';
  String get phoneAdded=>ru?'Телефон добавлен ✓':'Phone added ✓';
  String get getCode=>ru?'Получить код':'Get code';
  String get regSkip=>ru?'Пропустить':'Skip';
  String get regCodeInserted=>ru?'Код уже вставлен в поле — просто нажми «Подтвердить»':'Code is pre-filled — just tap Verify';
  String get regPhoneHintOpt=>ru?'+7 900 000-00-00 (необязательно)':'+7 900 000-00-00 (optional)';
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
class _VibeState extends State<VibeApp> with WidgetsBindingObserver{
  bool ready=false,logged=false,light=false,notifications=true,locked=false;
  String language='en',name='Alex',email='',username='';
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState st){
    // Безопасность: PIN при возврате из фона (если включено)
    if(st==AppLifecycleState.paused&&gPinOn&&gPinBg&&logged&&!locked&&mounted)setState(()=>locked=true);
  }
  Future<void> load()async{
    final p=await SharedPreferences.getInstance();
    final systemLang=WidgetsBinding.instance.platformDispatcher.locale.languageCode=='ru'?'ru':'en';
    final pinOn=p.getString('pin_hash')!=null;
    setState((){
      language=p.getString('language')??systemLang;
      light=p.getBool('light')??false;
      notifications=p.getBool('notifications')??true;
      name=p.getString('name')??'Alex';
      email=p.getString('email')??'';
      username=p.getString('username')??'';
      logged=p.getString('token')!=null;
      gShowOnline=p.getBool('show_online')??true;
      gShowTyping=p.getBool('show_typing')??true;
      gShowReads=p.getBool('show_reads')??true;
      gHidePreviews=p.getBool('hide_previews')??false;
      gPinOn=pinOn;
      gPinBg=p.getBool('pin_bg')??false;
      locked=pinOn; // при старте приложение всегда под PIN
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
  Future<Map<String,dynamic>> updateProfile(String n,String u,String? avatar,{String? bio})async{
    final d=await Api.put('/me',{'name':n,'username':u,if(avatar!=null)'avatar':avatar,if(bio!=null)'bio':bio});
    final p=await SharedPreferences.getInstance();
    final nn=(d['display_name']??n).toString();final uu=(d['username']??u).toString();
    await p.setString('name',nn);await p.setString('username',uu);
    setState((){name=nn;username=uu;});
    return Map<String,dynamic>.from(d as Map);
  }
  Future<void> logout()async{final p=await SharedPreferences.getInstance();await p.remove('token');setState(()=>logged=false);}
  @override Widget build(BuildContext context){
    if(!ready)return MaterialApp(debugShowCheckedModeBanner:false,theme:vibeTheme(true),home:const VibeSplash());
    if(logged&&gPinOn&&locked){
      // Безопасность: экран блокировки вместо всего приложения
      return MaterialApp(
        debugShowCheckedModeBanner:false,title:'vibe<3',locale:Locale(language),supportedLocales:const[Locale('en'),Locale('ru')],localizationsDelegates:const[GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
        themeMode:light?ThemeMode.light:ThemeMode.dark,theme:vibeTheme(false),darkTheme:vibeTheme(true),
        home:LockScreen(onUnlock:(){if(mounted)setState(()=>locked=false);},onSignOut:logout),
      );
    }
    return MaterialApp(debugShowCheckedModeBanner:false,title:'vibe<3',locale:Locale(language),supportedLocales:const[Locale('en'),Locale('ru')],localizationsDelegates:const[GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],themeMode:light?ThemeMode.light:ThemeMode.dark,theme:vibeTheme(false),darkTheme:vibeTheme(true),home:logged?Shell(name:name,username:username,light:light,language:language,notifications:notifications,onTheme:setTheme,onLanguage:setLanguage,onNotifications:setNotifications,onProfile:updateProfile,onLogout:logout):AuthScreen(onLogin:saveUser));
  }
}
class AuthScreen extends StatefulWidget{
  final Future<void> Function(String,String,String) onLogin;
  const AuthScreen({super.key,required this.onLogin});
  @override State<AuthScreen> createState()=>_AuthState();
}
class _AuthState extends State<AuthScreen>{
  bool register=false,busy=false,show1=false,show2=false;
  // Мастер регистрации v1.3.0: форма → код из SMS (телефон) → код из письма (почта) → аккаунт создан
  String regStage='form';String codePurpose='phone';String? devCode;String codeTarget='';
  bool phoneOk=false,emailOk=false;int resendIn=0;Timer? resendTimer;
  final email=TextEditingController(),name=TextEditingController(),username=TextEditingController(),pass=TextEditingController(),pass2=TextEditingController(),phone=TextEditingController(),code=TextEditingController();
  @override void initState(){
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  @override void dispose(){email.dispose();name.dispose();username.dispose();pass.dispose();pass2.dispose();phone.dispose();code.dispose();resendTimer?.cancel();super.dispose();}
  String normPhoneLocal(String p){String s=p.replaceAll(RegExp(r'[^0-9+]'),'');if(s.startsWith('8')&&s.length==11)s='+7'+s.substring(1);if(s.isNotEmpty&&!s.startsWith('+'))s='+$s';return s;}
  bool phoneValid(String p)=>RegExp(r'^\+\d{10,15}$').hasMatch(p);
  Future<void> _editServer()async{
    final c=TextEditingController(text:apiBase);
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:context.cSurf,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
      title:const Text('Адрес сервера',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Обычно менять не нужно. Формат: https://...',style:TextStyle(color:context.cMut,fontSize:12.5)),
        const SizedBox(height:12),
        TextField(controller:c,autofocus:true,keyboardType:TextInputType.url,style:TextStyle(fontSize:14),decoration:InputDecoration(hintText:'https://vibe3-api.onrender.com',filled:true,fillColor:context.cBg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:context.cLine)),isDense:true)),
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
      backgroundColor:context.cSurf,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
      title:Row(children:[Icon(ok?Icons.wifi_rounded:Icons.wifi_off_rounded,size:20,color:ok?green:pink),const SizedBox(width:8),Text(ok?'Связь есть':'Связи нет',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17))]),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Сервер: $apiBase',style:TextStyle(color:context.cMut,fontSize:11.5)),
        const SizedBox(height:12),
        Text(detail,style:const TextStyle(fontSize:13.5,height:1.45)),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Понятно'))],
    ));
  }
  Future<void> submit()async{
    final s=S(context);final e=email.text.trim().toLowerCase();final pw=pass.text;final n=name.text.trim();final u=username.text.trim().toLowerCase().replaceFirst('@','');
    if(!register){
      if(pw.length<6){snack(s.passwordShort);return;}
      setState(()=>busy=true);
      try{
        final d=await Api.post('/auth/login',{'email':e,'password':pw});
        Api.debugLog('login ok');
        await widget.onLogin(e,(d['user']['name']??n).toString(),d['token'].toString());
      }catch(err){snack(friendlyError(err,s));}
      finally{if(mounted)setState(()=>busy=false);}
      return;
    }
    // --- регистрация: форма → телефон-код → почта-код → create ---
    if(regStage=='form'){
      if(n.length<2){snack(s.nameRequired);return;}
      if(!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(u)){snack(s.usernameRules);return;}
      // v1.3.2: телефон НЕобязателен — можно оставить пустым и добавить потом в профиле
      final ph=normPhoneLocal(phone.text.trim());
      if(phone.text.trim().isNotEmpty&&!phoneValid(ph)){snack(s.ru?'Введи номер в формате +7 900 000-00-00 — или оставь поле пустым':'Enter phone like +7 900 000-00-00 — or leave it empty');return;}
      if(!e.contains('@')||!e.contains('.')){snack(s.emailInvalid);return;}
      if(pw.length<6){snack(s.passwordShort);return;}
      if(pass2.text!=pw){snack(s.passwordsMismatch);return;}
      await requestCode(phone.text.trim().isNotEmpty?'phone':'email');
      return;
    }
    await verifyCode();
  }
  Future<void> requestCode(String purpose)async{
    final s=S(context);final ph=normPhoneLocal(phone.text.trim());final e=email.text.trim().toLowerCase();
    setState(()=>busy=true);
    try{
      final d=await Api.post('/auth/request-code',{'purpose':purpose,'target':purpose=='phone'?ph:e});
      final dev=(d['devCode']??'').toString();
      if(mounted)setState((){
        regStage='code';codePurpose=purpose;
        devCode=dev.isEmpty?null:dev;
        codeTarget=purpose=='phone'?ph:e;code.text='';
        // v1.3.2: пока шлюз не подключён — код показан на экране и сразу вставлен в поле
        if(dev.isNotEmpty)code.text=dev;
        resendIn=30;
      });
      resendTimer?.cancel();
      resendTimer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted){resendTimer?.cancel();return;}if(resendIn<=1){resendTimer?.cancel();if(mounted)setState(()=>resendIn=0);}else setState(()=>resendIn--);});
    }catch(err){snack(friendlyError(err,s));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> verifyCode()async{
    final s=S(context);final ph=normPhoneLocal(phone.text.trim());final e=email.text.trim().toLowerCase();
    final c=code.text.trim();
    if(c.length!=6){snack(s.codeInvalid);return;}
    setState(()=>busy=true);
    try{
      await Api.post('/auth/verify-code',{'purpose':codePurpose,'target':codePurpose=='phone'?ph:e,'code':c});
      if(!mounted)return;
      if(codePurpose=='phone'){
        setState(() {phoneOk=true;devCode=null;});
        await requestCode('email');
      }else{
        setState(() {emailOk=true;});
        await createAccount();
      }
    }catch(err){
      snack(friendlyError(err,s));
    }
    finally{if(mounted)setState(()=>busy=false);}
  }
  // v1.3.2: пропустить шаг телефона — номер можно добавить потом в профиле
  Future<void> skipPhone()async{
    if(!mounted)return;
    setState(()=>phoneOk=false);
    await requestCode('email');
  }
  Future<void> createAccount()async{
    final s=S(context);final e=email.text.trim().toLowerCase();final pw=pass.text;final n=name.text.trim();final u=username.text.trim().toLowerCase().replaceFirst('@','');final ph=phoneOk?normPhoneLocal(phone.text.trim()):'';
    setState(()=>busy=true);
    try{
      final d=await Api.post('/auth/register',{'email':e,'name':n,'username':u,'password':pw,'phone':ph});
      Api.debugLog('register ok user=$u');
      await widget.onLogin(e,n,d['token'].toString());
    }catch(err){
      final x=err.toString();
      // номер/почта уже заняты — возвращаем на форму
      if(x.contains('email_exists')||x.contains('username_taken')||x.contains('phone_taken')){if(mounted)setState(()=>regStage='form');}
      snack(friendlyError(err,s));
    }
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    final dark=Theme.of(context).brightness==Brightness.dark;
    // системные панели подстраиваются под тему мгновенно
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:Colors.transparent,
      statusBarIconBrightness:dark?Brightness.light:Brightness.dark,
      systemNavigationBarColor:context.cBg,
      systemNavigationBarIconBrightness:dark?Brightness.light:Brightness.dark,
      systemNavigationBarDividerColor:context.cBg,
      systemNavigationBarContrastEnforced:false,
    ));
    return Scaffold(
      backgroundColor:context.cBg,
      extendBody:true,
      body:SafeArea(
        child:Container(
          color:context.cBg,
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
                            Column(
                              crossAxisAlignment:CrossAxisAlignment.start,
                              children:[
                                _VibeWordmark(fontSize:27),
                                SizedBox(height:2),
                                Text('private. personal. yours.',style:TextStyle(color:context.cMut,fontSize:12,fontWeight:FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height:42),
                        Text(register?s.createAccount:s.welcomeBack,style:const TextStyle(fontSize:36,fontWeight:FontWeight.w900,letterSpacing:-1.2,height:1.05)),
                        const SizedBox(height:9),
                        Text(register?s.joinVibe:s.signInContinue,style:TextStyle(color:context.cMut,fontSize:14,height:1.45)),
                        const SizedBox(height:26),
                        Row(children:[
                          Expanded(child:_AuthMode(label:s.signIn,active:!register,onTap:busy?null:(){FocusScope.of(context).unfocus();setState(() {register=false;regStage='form';});})),
                          const SizedBox(width:10),
                          Expanded(child:_AuthMode(label:s.createAccount,active:register,onTap:busy?null:(){FocusScope.of(context).unfocus();setState(()=>register=true);})),
                        ]),
                        const SizedBox(height:20),
                        if(register&&regStage=='code')
                          _RegCodeStep(
                            purpose:codePurpose,target:codeTarget,devCode:devCode,busy:busy,
                            controller:code,
                            resendIn:resendIn,
                            phoneDone:phoneOk,
                            onResend:resendIn>0||busy?null:()=>requestCode(codePurpose),
                            onBack:busy?null:(){resendTimer?.cancel();setState(() {regStage='form';devCode=null;code.text='';});},
                            onSkip:codePurpose=='phone'&&!busy?skipPhone:null,
                          )
                        else ...[
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
                                _AuthField(controller:phone,icon:Icons.call_outlined,hint:s.regPhoneHintOpt,keyboardType:TextInputType.phone),
                                const SizedBox(height:11),
                              ])
                            :const SizedBox.shrink(key:ValueKey('login-fields')),
                        ),
                        _AuthField(controller:email,icon:Icons.mail_outline_rounded,hint:register?s.email:s.loginPhoneHint,keyboardType:TextInputType.emailAddress),
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
                        _GradientButton(height:56,radius:17,busy:busy,onTap:submit,icon:register?(regStage=='code'?Icons.verified_outlined:Icons.arrow_forward_rounded):Icons.login_rounded,label:register?(regStage=='code'?s.regVerify:s.createAccount):s.signIn),
                        const SizedBox(height:16),
                        Row(
                          mainAxisAlignment:MainAxisAlignment.center,
                          children:[
                            Icon(Icons.lock_outline_rounded,size:13,color:(dark?context.cMut:Colors.black45)),
                            const SizedBox(width:6),
                            Text(s.securitySub,textAlign:TextAlign.center,style:TextStyle(color:context.cMut,fontSize:11.5,height:1.3)),
                          ],
                        ),
                        const SizedBox(height:6),
                        Center(child:TextButton.icon(
                          onPressed:busy?null:_editServer,
                          style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),minimumSize:Size.zero),
                          icon:Icon(Icons.dns_outlined,size:14,color:context.cMut.withOpacity(.8)),
                          label:Text(apiBase.replaceAll(RegExp(r'^https?://'),''),style:TextStyle(color:context.cMut,fontSize:10.5)),
                        )),
                        Center(child:TextButton.icon(
                          onPressed:busy?null:_checkConn,
                          style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),minimumSize:Size.zero),
                          icon:Icon(Icons.wifi_tethering_rounded,size:14,color:context.cMut.withOpacity(.8)),
                          label:Text('проверить связь',style:TextStyle(color:context.cMut,fontSize:10.5)),
                        )),
                        const SizedBox(height:22),
                        Center(
                          child:TextButton(
                            onPressed:busy?null:(){FocusScope.of(context).unfocus();setState(() {register=!register;regStage='form';});},
                            child:Text(register?s.alreadyHave:s.newToVibe,style:const TextStyle(fontWeight:FontWeight.w800)),
                          ),
                        ),
                        ],
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

// ===== Экран ввода кода подтверждения (SMS / почта) в мастере регистрации =====
class _RegCodeStep extends StatelessWidget{
  final String purpose,target;final String? devCode;final bool busy;final bool phoneDone;
  final TextEditingController controller;final int resendIn;final VoidCallback? onResend,onBack,onSkip;
  const _RegCodeStep({required this.purpose,required this.target,required this.devCode,required this.busy,required this.controller,required this.resendIn,required this.phoneDone,this.onResend,this.onBack,this.onSkip});
  @override Widget build(BuildContext context){
    final s=S(context);
    return Container(key:const ValueKey('reg-code-step'),margin:const EdgeInsets.only(bottom:4),padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:context.cSurf,borderRadius:BorderRadius.circular(24),border:Border.all(color:context.cLine)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Container(width:44,height:44,decoration:BoxDecoration(color:(purpose=='phone'?purple:pink).withOpacity(.15),borderRadius:BorderRadius.circular(14)),child:Icon(purpose=='phone'?Icons.call_outlined:Icons.mark_email_unread_outlined,color:purpose=='phone'?purple:pink)),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(purpose=='phone'?s.regPhoneTitle:s.regEmailTitle,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
          const SizedBox(height:2),
          Text((purpose=='phone'?s.regCodeSentPhone:s.regCodeSentEmail)+' '+target,style:TextStyle(color:context.cMut,fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),
        ])),
      ]),
      if(phoneDone)...[
        const SizedBox(height:12),
        Row(children:[Icon(Icons.check_circle_rounded,size:16,color:green),const SizedBox(width:6),Text(s.phoneVerifiedOk,style:TextStyle(color:green,fontSize:12.5,fontWeight:FontWeight.w800))]),
      ],
      const SizedBox(height:16),
      TextField(
        controller:controller,enabled:!busy,autofocus:true,maxLength:6,
        keyboardType:TextInputType.number,
        textAlign:TextAlign.center,
        style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,letterSpacing:12),
        decoration:InputDecoration(hintText:'——',counterText:'',filled:true,fillColor:context.cBg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:context.cLine)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:context.cLine)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:pink,width:1.6))),
      ),
      if(devCode!=null)...[
        const SizedBox(height:12),
        Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:purple.withOpacity(.10),borderRadius:BorderRadius.circular(14),border:Border.all(color:purple.withOpacity(.35))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(s.regCodeDevNote,style:TextStyle(color:context.cMut,fontSize:11,height:1.35)),
          const SizedBox(height:6),
          Text('Код: $devCode',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,letterSpacing:4,color:purple)),
          const SizedBox(height:5),
          Row(children:[Icon(Icons.check_circle_rounded,size:13,color:green),const SizedBox(width:5),Expanded(child:Text(s.regCodeInserted,style:TextStyle(color:green,fontSize:11,fontWeight:FontWeight.w800)))]),
        ])),
      ],
      const SizedBox(height:14),
      Row(children:[
        if(onSkip!=null)...[
          Expanded(child:TextButton(onPressed:onSkip,style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(vertical:14)),child:Text(s.regSkip,textAlign:TextAlign.center,style:TextStyle(fontSize:12.5,color:context.cMut,fontWeight:FontWeight.w800)))),
          const SizedBox(width:8),
        ],
        Expanded(child:TextButton(onPressed:onBack,style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(vertical:14)),child:Text(s.cancel))),
        const SizedBox(width:10),
        Expanded(flex:2,child:TextButton(onPressed:onResend,style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(vertical:14)),child:Text(resendIn>0?'${s.regResendIn} $resendIn с':s.regCodeResend,textAlign:TextAlign.center,style:TextStyle(fontSize:12.5,color:resendIn>0?context.cMut:purple,fontWeight:FontWeight.w800)))),
      ]),
    ]));
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
        child:Center(child:Text(label,style:TextStyle(fontWeight:FontWeight.w900,fontSize:13,letterSpacing:.1,color:active?Colors.white:context.cMut))),
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
        color:dark?context.cSurf.withOpacity(.7):Colors.white,
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:dark?context.cLine:Colors.black12),
      ),
      padding:const EdgeInsets.only(left:16),
      child:Row(
        children:[
          Icon(widget.icon,color:dark?context.cMut:Colors.black54,size:20),
          const SizedBox(width:8),
          Expanded(
            child:Stack(
              alignment:Alignment.centerLeft,
              children:[
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable:widget.controller,
                  builder:(context,value,_){
                    if(value.text.isNotEmpty)return const SizedBox.shrink();
                    return IgnorePointer(child:Text(widget.hint,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:context.cMut,fontSize:16)));
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
                  backgroundCursorColor:context.cMut,
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
  if(x.contains('phone_taken'))return s.phoneTaken;
  if(x.contains('invalid_phone'))return s.ru?'Проверь номер телефона':'Check the phone number';
  if(x.contains('code_invalid'))return s.codeInvalid;
  if(x.contains('code_expired'))return s.codeExpired;
  if(x.contains('phone_not_verified'))return s.ru?'Сначала подтверди номер':'Verify your phone first';
  if(x.contains('email_not_verified'))return s.ru?'Сначала подтверди почту':'Verify your email first';
  if(x.contains('http_429'))return ru429(s);
  if(x.contains('http_5'))return s.connectionError+' · сервер недоступен, попробуй через минуту';
  if(x.contains('TimeoutException')||x.contains('timeout'))return s.connectionError+' · сервер не отвечает';
  if(x.contains('Failed host lookup'))return s.connectionError+' · адрес не найден — проверь сервер внизу экрана';
  if(x.contains('SocketException')||x.contains('ClientException')||x.contains('HandshakeException')||x.contains('Connection')||x.contains('connection'))return s.connectionError;
  if(x.contains('http_'))return s.connectionError+' · '+x;
  return s.connectionError+' · '+x;
}
String ru429(AppStrings s)=>s.connectionError+' · слишком много попыток, подожди минуту';

class Chat{final String id;String name,preview,time;bool online,isGroup;int unread;DateTime? lastAt;String peerAvatar,peerId;Chat(this.id,this.name,this.preview,this.time,{this.online=false,this.unread=0,this.isGroup=false,this.lastAt,this.peerAvatar='',this.peerId=''});}
class UserX{final String id,name,username,avatar;UserX(this.id,this.name,this.username,{this.avatar=''});}
class Msg{final String id,text,sender,type,mediaUrl;final bool mine;final DateTime createdAt;Msg(this.id,this.text,this.sender,this.mine,{this.type='text',this.mediaUrl='',DateTime? createdAt}):createdAt=createdAt??DateTime.now();}
class Shell extends StatefulWidget{
  final String name,username,language;final bool light,notifications;
  final ValueChanged<bool> onTheme,onNotifications;final ValueChanged<String> onLanguage;
  final Future<Map<String,dynamic>> Function(String,String,String?,{String? bio}) onProfile;final VoidCallback onLogout;
  const Shell({super.key,required this.name,required this.username,required this.light,required this.language,required this.notifications,required this.onTheme,required this.onLanguage,required this.onNotifications,required this.onProfile,required this.onLogout});
  @override State<Shell> createState()=>_ShellState();
}
class _ShellState extends State<Shell>{
  int tab=0;
  IO.Socket? gsock;
  Map<String,dynamic>? banner;Timer? bannerHide;bool incomingOpen=false;
  @override void initState(){super.initState();_wire();}
  @override void dispose(){bannerHide?.cancel();super.dispose();}
  Future<void> _wire()async{
    try{gsock=await CallKit.socket();}catch(_){return;}
    gsock!.on('notify',_onNotify);
    gsock!.on('call',_onCall);
    gsock!.on('call:end',_onCallEnd);
    gsock!.on('chatDeleted',(_)=>chatsChanged.value++);
  }
  void _onNotify(d){
    if(d is! Map||CallKit.inCall)return;
    if(widget.notifications!=true)return; // живой тумблер уведомлений
    if((d['chatId']??'').toString()==activeOpenChatId)return;
    if(!mounted)return;
    SystemSound.play(SystemSoundType.alert);
    setState(()=>banner=Map<String,dynamic>.from(d));
    bannerHide?.cancel();
    bannerHide=Timer(const Duration(seconds:4),(){if(mounted)setState(()=>banner=null);});
  }
  void _onCall(d){
    if(d is! Map||CallKit.inCall||incomingOpen)return;
    incomingOpen=true;
    showDialog(context:context,barrierDismissible:false,builder:(_)=>IncomingScreen(data:d.cast<String,dynamic>(),onClosed:()=>incomingOpen=false));
  }
  void _onCallEnd(_){
    if(incomingOpen&&mounted){incomingOpen=false;Navigator.of(context,rootNavigator:true).pop();}
  }
  Future<void> _openBanner()async{
    final b=banner;if(b==null)return;
    setState(()=>banner=null);
    await openChat(Chat((b['chatId']??'').toString(),(b['fromName']??'?').toString(),(b['body']??'').toString(),''));
  }
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
  // Звонок прямо из профиля: находим/создаём личный чат и сразу набираем
  Future<void> callUser(UserX u,bool video)async{
    try{
      final d=await Api.post('/chats/direct',{'userId':u.id});
      final chatId=(d['id']??'').toString();
      if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>CallPage(call:CallStart(chatId:chatId,name:u.name,peerId:u.id,video:video))));
    }catch(e){
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).openChatError)));
    }
  }
  Future<void> openProfile(UserX u)async{
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>UserProfilePage(userId:u.id,onMessage:openPerson,onCall:callUser)));
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    final current=tab==0
      ?Chats(onOpen:openChat,onNewChat:()=>setState(()=>tab=1))
      :tab==1
        ?Contacts(onOpenProfile:openProfile,onOpenGroup:openChat)
        :tab==2
          ?Calls(onOpenChat:openChat)
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
      backgroundColor:context.cBg,
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
            if(banner!=null)Positioned(
              top:8,left:14,right:14,
              child:_EntryAnimation(delay:const Duration(milliseconds:10),child:_NotifyBanner(data:banner!,onTap:_openBanner,onClose:()=>setState(()=>banner=null))),
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
              color:context.cSurf.withOpacity(.92),
              borderRadius:BorderRadius.circular(24),
              border:Border.all(color:context.cLine.withOpacity(.9)),
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
              Icon(active?activeIcon:icon,size:21,color:active?Colors.white:context.cMut),
              const SizedBox(height:3),
              Text(label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:active?Colors.white:context.cMut)),
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
  @override void initState(){super.initState();load();chatsChanged.addListener(_reload);}
  @override void dispose(){chatsChanged.removeListener(_reload);super.dispose();}
  void _reload(){if(mounted)load();}
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
          peerAvatar:(x['peer_avatar']??'').toString(),
          peerId:(x['peer_id']??'').toString(),
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
  Future<void> _chatSheet(Chat c)async{
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      if(c.unread>0)ListTile(leading:const Icon(Icons.done_all_rounded),title:Text(s.markRead),onTap:(){Navigator.pop(context);Api.post('/chats/'+c.id+'/read',{}).then((_){if(mounted)load();}).catchError((_){});}),
      ListTile(leading:const Icon(Icons.delete_outline_rounded),title:Text(s.deleteChat),onTap:()async{
        Navigator.pop(context);
        final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(s.deleteChat),content:Text(s.deleteChatConfirm),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(s.cancel)),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(s.delete))]));
        if(ok!=true)return;
        try{await Api.delete('/chats/'+c.id);if(mounted){load();ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.chatDeleted)));}}catch(_){}
      }),
    ])));
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
    return Container(color:context.cBg,child:Stack(
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
                      Text(s.chats.toLowerCase(),style:TextStyle(color:context.cMut,fontSize:11,fontWeight:FontWeight.w700,letterSpacing:.7)),
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
                        color:active?null:context.cSurf.withOpacity(.6),
                        borderRadius:BorderRadius.circular(13),
                        border:Border.all(color:active?Colors.white.withOpacity(.12):context.cLine),
                        boxShadow:active?[BoxShadow(color:pink.withOpacity(.20),blurRadius:14,offset:const Offset(0,4))]:null,
                      ),
                      child:Text(label,style:TextStyle(fontSize:12.5,fontWeight:FontWeight.w800,color:active?Colors.white:context.cMut)),
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
                        child:Tile(chat:filtered[i],tap:()=>openTile(filtered[i]),longPress:()=>_chatSheet(filtered[i])),
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
      backgroundColor:context.cBg,
      appBar:AppBar(
        backgroundColor:context.cBg,
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
        color:dark?context.cSurf.withOpacity(.65):Colors.white,
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:dark?context.cLine:Colors.black12),
      ),
      padding:const EdgeInsets.only(left:14,right:8),
      child:Row(
        children:[
          Icon(Icons.search_rounded,color:context.cMut,size:21),
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
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  const _BareField({this.controller,required this.hint,this.icon,this.keyboardType,this.maxLines=1,this.maxLength,this.onChanged});
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
            child:Icon(widget.icon,color:context.cMut,size:21),
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
                        child:Text(widget.hint,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:context.cMut,fontSize:15,fontWeight:FontWeight.w500)),
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
                  inputFormatters:widget.maxLength!=null?[LengthLimitingTextInputFormatter(widget.maxLength)]:null,
                  style:const TextStyle(fontWeight:FontWeight.w600,fontSize:15),
                  cursorColor:pink,
                  backgroundCursorColor:context.cMut,
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
  final Chat chat;final VoidCallback tap;final VoidCallback? longPress;
  const Tile({super.key,required this.chat,required this.tap,this.longPress});
  @override Widget build(BuildContext context){
    final s=S(context);
    return Material(
      type:MaterialType.transparency,
      child:InkWell(
        onTap:tap,
        onLongPress:longPress,
        borderRadius:BorderRadius.circular(22),
        splashColor:pink.withOpacity(.06),
        highlightColor:pink.withOpacity(.035),
        child:Container(
          padding:const EdgeInsets.symmetric(horizontal:6,vertical:11),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(22),
            border:Border(bottom:BorderSide(color:context.cLine.withOpacity(.52),width:.7)),
          ),
          child:Row(
            children:[
              Avatar(name:chat.name,size:54,url:chat.peerAvatar),
              const SizedBox(width:12),
              Expanded(
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(chat.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15.5,fontWeight:FontWeight.w800)),
                    const SizedBox(height:4),
                    Builder(builder:(_){
                      // Приватность: скрытие текста сообщений в списке
                      final prev=gHidePreviews&&chat.preview.isNotEmpty?s.hiddenPreview:chat.preview;
                      return Text(prev.isEmpty?s.active:prev,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:context.cMut,fontSize:13));
                    }),
                  ],
                ),
              ),
              const SizedBox(width:10),
              Column(
                mainAxisAlignment:MainAxisAlignment.center,
                crossAxisAlignment:CrossAxisAlignment.end,
                children:[
                  if(chat.time.isNotEmpty)Text(chat.time,style:TextStyle(color:context.cMut,fontSize:11,fontWeight:FontWeight.w700)),
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
  final String name;final double size;final String? url;
  const Avatar({super.key,required this.name,this.size=46,this.url});
  // Кэш декодированных аватарок (data URL -> байты), чтобы не декодировать на каждый кадр
  static final Map<String,Uint8List> _mem={};
  static Uint8List? bytes(String? url){
    if(url==null||url.isEmpty||!url.startsWith('data:image'))return null;
    final hit=_mem[url];if(hit!=null)return hit;
    try{
      final i=url.indexOf('base64,');
      if(i<0)return null;
      final b=base64Decode(url.substring(i+7));
      if(b.isNotEmpty){if(_mem.length>60)_mem.clear();_mem[url]=b;return b;}
    }catch(_){}
    return null;
  }
  @override Widget build(BuildContext context){
    final img=bytes(url);
    if(img!=null){
      return Container(
        width:size,height:size,
        decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(size*.32),
          border:Border.all(color:Colors.white.withOpacity(.16),width:1),
          boxShadow:[BoxShadow(color:pink.withOpacity(.24),blurRadius:16,spreadRadius:-2)],
        ),
        child:ClipRRect(borderRadius:BorderRadius.circular(size*.32-(size>60?1.2:.8)),child:Image.memory(img,fit:BoxFit.cover,gaplessPlayback:true)),
      );
    }
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
  bool loading=true,sending=false,peerTyping=false,peerOnline=false,peerRead=false;IO.Socket? socket;String myId='',peerId='';
  // Приватность собеседника (с сервера): что ему можно показывать, а что скрыто у него
  String peerAvatar='';bool peerHideOnline=false,peerHideTyping=false,peerHideReads=false;
  // Защита от скриншотов по просьбе собеседника + запрет звонков у собеседника
  bool peerNoShots=false,peerNoCalls=false;bool _shotsNotified=false;
  int effect=0;double fxIntensity=.55;Timer? typingTimer,typingClear;

  @override void initState(){super.initState();activeOpenChatId=widget.chat.id;load();restoreFx();Api.debugLog('chat open id=${widget.chat.id} name=${widget.chat.name}');}
  @override void dispose(){
    if(activeOpenChatId==widget.chat.id)activeOpenChatId=null;
    // выходим из чата — возвращаем личную настройку запрета скриншотов
    if(peerNoShots){
      ()async{try{final p=await SharedPreferences.getInstance();await applySecureFlag(p.getBool('secure_mode')??false);}catch(_){}}();
    }
    socket?.disconnect();socket?.dispose();recorder.dispose();input.dispose();scroll.dispose();typingTimer?.cancel();typingClear?.cancel();super.dispose();
  }
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
        peerAvatar=(pr['avatar_url']??'').toString();
        peerHideOnline=pr['show_online']==false;
        peerHideTyping=pr['show_typing']==false;
        peerHideReads=pr['show_reads']==false;
        // приватность собеседника: в его чате скриншоты запрещены (защита его чатов)
        peerNoShots=pr['block_screenshots']==true;
        peerNoCalls=pr['allow_calls']==false;
        if(peerNoShots){
          applySecureFlag(true);
          if(mounted&&!_shotsNotified){
            _shotsNotified=true;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).shotsByPeer)));
          }
        }
        if(peerId.isNotEmpty&&mounted)setState((){});
      }catch(_){}
    }catch(_){}
    if(mounted){setState(()=>loading=false);WidgetsBinding.instance.addPostFrameCallback((_)=>scrollEnd());}
  }
  Future<void> markRead()async{try{await Api.post('/chats/'+widget.chat.id+'/read',{});}catch(_){}}
  Future<void> connectRealtime()async{
    final t=await Api.token();if(t==null)return;
    socket=IO.io(apiBase,IO.OptionBuilder().setTransports(['websocket']).setAuth({'token':t}).disableAutoConnect().build());
    socket!.onConnect((_){socket!.emit('joinChat',widget.chat.id);if(gShowOnline)socket!.emit('presence',true);});
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
      if(peerHideTyping)return; // приватность: собеседник скрыл «печатает...»
      if(((data['chatId']??'').toString())!=widget.chat.id)return;
      if(((data['userId']??'').toString())==myId)return;
      final typing=data['typing']==true;
      if(typing!=peerTyping)setState(()=>peerTyping=typing);
      typingClear?.cancel();
      if(typing)typingClear=Timer(const Duration(seconds:4),(){if(mounted)setState(()=>peerTyping=false);});
    });
    socket!.on('read',(d){
      if(!mounted||d is! Map)return;
      if(peerHideReads)return; // приватность: собеседник скрыл отчёты о прочтении
      if(((d['userId']??'').toString())==myId)return;
      if(!peerRead)setState(()=>peerRead=true);
    });
    socket!.on('messageDeleted',(d){
      if(!mounted||d is! Map)return;
      final id=(d['id']??'').toString();
      if(id.isNotEmpty&&msgs.any((m)=>m.id==id))setState(()=>msgs.removeWhere((m)=>m.id==id));
    });
    socket!.on('presence',(data){
      if(!mounted||data is! Map)return;
      if(peerHideOnline){if(peerOnline)setState(()=>peerOnline=false);return;} // приватность: собеседник скрыл «в сети»
      if(((data['userId']??'').toString())!=myId&&peerId.isNotEmpty&&((data['userId']??'').toString())==peerId){
        setState(()=>peerOnline=data['online']==true);
      }
    });
    socket!.connect();
  }
  void onInputChanged(String v){
    if(!gShowTyping)return; // приватность: не показываем «печатает...»
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
    final pageBg=dark?context.cBg:Color(0xFFF3F1FA);
    final chatSurface=dark?context.cSurf:Colors.white;
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
                      tooltip:'Назад',
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
                              Avatar(name:widget.chat.name,size:40,url:peerAvatar.isNotEmpty?peerAvatar:widget.chat.peerAvatar),
                              const SizedBox(width:10),
                              Expanded(
                                child:Column(
                                  mainAxisAlignment:MainAxisAlignment.center,
                                  crossAxisAlignment:CrossAxisAlignment.start,
                                  children:[
                                    Text(widget.chat.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
                                    const SizedBox(height:2),
                                    Builder(builder:(_){
                                      final onlineOk=(peerOnline||widget.chat.online)&&!peerHideOnline;
                                      final typingOk=peerTyping&&!peerHideTyping;
                                      return Text(
                                        typingOk?s.typingNow:onlineOk?s.online:s.active,
                                        style:TextStyle(color:typingOk?pink:onlineOk?purple:context.cMut,fontSize:11,fontWeight:typingOk?FontWeight.w800:FontWeight.w600),
                                      );
                                    }),
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
                      ?EmptyState(icon:Icons.auto_awesome_outlined,title:s.noMessages,sub:s.noMessagesSub)
                      :ListView.builder(
                        controller:scroll,
                        padding:const EdgeInsets.fromLTRB(14,18,14,14),
                        itemCount:msgs.length+(peerTyping&&!peerHideTyping?1:0),
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
                            Bubble(key:ValueKey(msgs[i].id),msg:msgs[i],read:peerRead&&!peerHideReads,chatId:widget.chat.id),
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
                color:dark?context.cSurf2:Colors.white,
                borderRadius:BorderRadius.circular(20),
                border:Border.all(color:dark?context.cLine:Colors.black12),
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
    // Личный чат: полноценный профиль человека (Telegram-стиль). Никаких «участников» в личных чатах.
    if(!widget.chat.isGroup){
      String pid=peerId;
      if(pid.isEmpty){
        try{final pr=await Api.get('/chats/'+widget.chat.id+'/peer');pid=(pr['id']??'').toString();}catch(_){}
      }
      if(pid.isNotEmpty&&context.mounted){
        await Navigator.push(context,MaterialPageRoute(builder:(_)=>UserProfilePage(
          userId:pid,
          onMessage:(u)async{if(context.mounted)Navigator.pop(context);},
          onCall:(u,video)async{if(context.mounted){Navigator.pop(context);openCall(context,video);}},
        )));
        return;
      }
      if(!context.mounted)return;
      // fallback без «участников»: только аватар, имя и действия
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
                const SizedBox(height:15),
                ListTile(leading:Icon(Icons.auto_awesome_rounded),title:Text(s.effects),subtitle:Text(s.intensity,style:TextStyle(color:context.cMut)),onTap:(){Navigator.pop(context);showEffects(context);}),
                ListTile(leading:const Icon(Icons.refresh_rounded),title:Text(s.refresh),onTap:(){Navigator.pop(context);setState(()=>loading=true);load();}),
              ],
            ),
          ),
        ),
      );
      return;
    }
    // Группа: лист с участниками и действиями
    if(!context.mounted)return;
    showModalBottomSheet(
      context:context,
      isScrollControlled:true,
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
              const SizedBox(height:15),
              _GroupMembers(chatId:widget.chat.id),
              ListTile(leading:Icon(Icons.auto_awesome_rounded),title:Text(s.effects),subtitle:Text(s.intensity,style:TextStyle(color:context.cMut)),onTap:(){Navigator.pop(context);showEffects(context);}),
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
  void openCall(BuildContext context,bool video){
    if(widget.chat.isGroup){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).groupOnlyCall)));
      return;
    }
    if(peerNoCalls){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S(context).callsBlockedByPeer)));
      return;
    }
    Navigator.push(context,MaterialPageRoute(builder:(_)=>CallPage(call:CallStart(chatId:widget.chat.id,name:widget.chat.name,peerId:peerId,video:video))));
  }
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
        decoration:BoxDecoration(color:context.cBg.withOpacity(.72),borderRadius:BorderRadius.circular(12),border:Border.all(color:context.cLine.withOpacity(.8))),
        child:Text(txt,style:TextStyle(color:context.cMut,fontSize:11.5,fontWeight:FontWeight.w700)),
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
            child:Container(width:7,height:7,decoration:BoxDecoration(shape:BoxShape.circle,color:(dark?context.cMut:pink).withOpacity(.45+.5*up))),
          );
        }
        return Container(
          padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),
          decoration:BoxDecoration(
            color:dark?context.cSurf2:Colors.white,
            borderRadius:const BorderRadius.only(topLeft:Radius.circular(18),topRight:Radius.circular(18),bottomLeft:Radius.circular(5),bottomRight:Radius.circular(18)),
            border:Border.all(color:dark?context.cLine:Colors.black12),
          ),
          child:Row(mainAxisSize:MainAxisSize.min,children:[dot(0),const SizedBox(width:5),dot(1),const SizedBox(width:5),dot(2)]),
        );
      },
    );
  }
}

class Bubble extends StatefulWidget{
  final Msg msg;final bool read;final String chatId;
  const Bubble({super.key,required this.msg,this.read=false,this.chatId=''});
  @override State<Bubble> createState()=>_BubbleState();
}
class _BubbleState extends State<Bubble> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  late final Animation<double> scale;
  AudioPlayer? player;StreamSubscription? subPos,subState,subDur;bool playing=false;Duration apos=Duration.zero,adur=Duration.zero;
  @override void initState(){
    super.initState();
    controller=AnimationController(vsync:this,duration:const Duration(milliseconds:280));
    scale=Tween<double>(begin:.90,end:1).animate(CurvedAnimation(parent:controller,curve:Curves.easeOutBack));
    controller.forward();
  }
  @override void dispose(){controller.dispose();subPos?.cancel();subState?.cancel();subDur?.cancel();player?.dispose();super.dispose();}
  Future<void> _playAudio()async{
    final s=S(context);
    try{
      if(playing){await player?.pause();if(mounted)setState(()=>playing=false);return;}
      if(player==null){
        player=AudioPlayer();
        subPos=player!.onPositionChanged.listen((d){if(mounted)setState(()=>apos=d);});
        subDur=player!.onDurationChanged.listen((d){if(mounted)setState(()=>adur=d);});
        subState=player!.onPlayerStateChanged.listen((st){if(st==PlayerState.completed&&mounted){setState((){playing=false;apos=Duration.zero;});}});
      }
      final bytes=base64Decode(widget.msg.mediaUrl.substring(widget.msg.mediaUrl.indexOf(',')+1));
      await player!.play(BytesSource(bytes,mimeType:'audio/mp4'));
      if(mounted)setState(()=>playing=true);
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.mediaFailed)));
    }
  }
  Future<void> _msgSheet()async{
    final s=S(context);final msg=widget.msg;
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      if(msg.type=='text'&&msg.text.isNotEmpty)
        ListTile(leading:const Icon(Icons.copy_rounded),title:Text(s.copy),onTap:(){Navigator.pop(context);Clipboard.setData(ClipboardData(text:msg.text));ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.copied)));}),
      if(msg.type=='image'||msg.type=='video'||msg.type=='audio')
        ListTile(leading:Icon(msg.type=='image'?Icons.image_rounded:(msg.type=='video'?Icons.play_circle_rounded:Icons.graphic_eq_rounded)),title:Text(msg.type=='image'?(s.ru?'Открыть фото':'Open photo'):(msg.type=='video'?(s.ru?'Смотреть видео':'Play video'):(s.ru?'Слушать':'Listen'))),onTap:(){Navigator.pop(context);_openMedia();}),
      if(msg.mine&&widget.chatId.isNotEmpty)
        ListTile(leading:const Icon(Icons.delete_outline_rounded),title:Text(s.deleteMsg),onTap:()async{
          Navigator.pop(context);
          final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(s.deleteMsg),content:Text(s.deleteMsgConfirm),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(s.cancel)),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(s.delete))]));
          if(ok!=true)return;
          try{await Api.delete('/chats/'+widget.chatId+'/messages/'+msg.id);}catch(_){}
        }),
    ])));
  }
  void _openMedia(){
    if(widget.msg.type=='image'){Navigator.push(context,MaterialPageRoute(builder:(_)=>ImageViewerPage(mediaUrl:widget.msg.mediaUrl,name:widget.msg.text)));}
    else if(widget.msg.type=='video'){Navigator.push(context,MaterialPageRoute(builder:(_)=>VideoViewerPage(mediaUrl:widget.msg.mediaUrl,name:widget.msg.text)));}
    else if(widget.msg.type=='audio'){_playAudio();}
  }
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    final msg=widget.msg;
    final s=S(context);
    final cs=Theme.of(context).colorScheme;
    final incoming=dark?context.cSurf2:Colors.white;
    final time=_fmtTime(msg.createdAt);
    Widget content;
    if(msg.type=='image'&&msg.mediaUrl.isNotEmpty){
      content=GestureDetector(onTap:_openMedia,onLongPress:_msgSheet,child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
        ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(msg.mediaUrl.substring(msg.mediaUrl.indexOf(',')+1)),width:230,height:230,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(width:230,height:230,color:context.cSurf,child:Icon(Icons.broken_image_rounded,color:context.cMut)))),
        const SizedBox(height:5),
        _MsgMeta(time:time,mine:msg.mine,dark:dark,read:widget.read),
      ]));
    }else if(msg.type=='video'&&msg.mediaUrl.isNotEmpty){
      content=GestureDetector(onTap:_openMedia,onLongPress:_msgSheet,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:230,height:140,decoration:BoxDecoration(color:Colors.black.withOpacity(.45),borderRadius:BorderRadius.circular(12)),child:const Center(child:Icon(Icons.play_circle_fill_rounded,color:Colors.white,size:52))),
        const SizedBox(height:6),
        Text(msg.text,style:TextStyle(color:msg.mine?Colors.white:cs.onSurface,fontSize:13)),
        const SizedBox(height:4),
        _MsgMeta(time:time,mine:msg.mine,dark:dark,read:widget.read),
      ]));
    }else if(msg.type=='audio'&&msg.mediaUrl.isNotEmpty){
      final total=adur.inSeconds>0?adur.inSeconds:0;
      final prog=total>0?(apos.inSeconds/total).clamp(0.0,1.0):0.0;
      content=GestureDetector(onTap:_openMedia,onLongPress:_msgSheet,child:Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(playing?Icons.pause_circle_rounded:Icons.play_circle_fill_rounded,color:msg.mine?Colors.white:pink,size:36),
        const SizedBox(width:8),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          SizedBox(width:130,child:ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:prog,minHeight:4,backgroundColor:msg.mine?Colors.white24:context.cLine,valueColor:AlwaysStoppedAnimation(msg.mine?Colors.white:pink)))),
          const SizedBox(height:4),
          Text(playing||apos>Duration.zero?'${apos.inMinutes.remainder(60).toString().padLeft(2,'0')}:${apos.inSeconds.remainder(60).toString().padLeft(2,'0')}':s.voiceMessage,style:TextStyle(color:msg.mine?Colors.white70:cs.onSurface,fontSize:11.5)),
        ]),
        const SizedBox(width:8),
        _MsgMeta(time:time,mine:msg.mine,dark:dark,read:widget.read),
      ]));
    }else{
      content=GestureDetector(onLongPress:_msgSheet,child:Row(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.end,children:[
        Flexible(child:Text(msg.text,style:TextStyle(color:msg.mine?Colors.white:cs.onSurface,fontSize:15,height:1.3))),
        const SizedBox(width:8),
        _MsgMeta(time:time,mine:msg.mine,dark:dark,read:widget.read),
      ]));
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
              border:msg.mine?null:Border.all(color:dark?context.cLine:Colors.black12),
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
  final String time;final bool mine;final bool dark;final bool read;
  const _MsgMeta({required this.time,required this.mine,required this.dark,this.read=false});
  @override Widget build(BuildContext context){
    return Row(mainAxisSize:MainAxisSize.min,children:[
      Text(time,style:TextStyle(color:mine?Colors.white.withOpacity(.75):context.cMut,fontSize:10.5,fontWeight:FontWeight.w700)),
      if(mine) ...[
        const SizedBox(width:3),
        Icon(read?Icons.done_all_rounded:Icons.done_rounded,size:13,color:read?const Color(0xFF8FF7C1):Colors.white.withOpacity(.75)),
      ],
    ]);
  }
}

// Участники группы + добавление (живые кнопки)
class _GroupMembers extends StatefulWidget{
  final String chatId;const _GroupMembers({required this.chatId});
  @override State<_GroupMembers> createState()=>_GroupMembersState();
}
class _GroupMembersState extends State<_GroupMembers>{
  List<UserX> members=[];bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final a=await Api.get('/chats/'+widget.chatId+'/members');
      members=(a as List).map((x)=>UserX((x['id']??'').toString(),(x['display_name']??'').toString(),(x['username']??'').toString())).toList();
    }catch(_){}
    if(mounted)setState(()=>loading=false);
  }
  void _add(){
    final s=S(context);
    showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(_)=>SafeArea(child:SizedBox(height:430,child:StatefulBuilder(builder:(ctx,setSheet){
      List<UserX> found=[];bool searching=false;String lastQ='';
      Future<void> doSearch(String q)async{
        if(q==lastQ)return;lastQ=q;
        setSheet(()=>searching=true);
        try{final a=await Api.get('/users?q='+Uri.encodeQueryComponent(q));found=(a as List).map((x)=>UserX((x['id']??'').toString(),(x['display_name']??'User').toString(),(x['username']??'').toString())).toList();}catch(_){found=[];}
        setSheet(()=>searching=false);
      }
      return Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,10,16,6),child:SearchBox(hint:s.addMember,onChanged:(v){doSearch(v.trim());})),
        Expanded(child:searching
          ?const Center(child:CircularProgressIndicator(strokeWidth:2))
          :found.isEmpty
            ?Center(child:Text(s.noPeople,style:TextStyle(color:context.cMut)))
            :ListView.builder(itemCount:found.length,itemBuilder:(_,i)=>ListTile(
              leading:Avatar(name:found[i].name,size:40),
              title:Text(found[i].name),
              subtitle:Text('@'+found[i].username,style:TextStyle(color:context.cMut,fontSize:12)),
              onTap:()async{
                try{await Api.post('/chats/'+widget.chatId+'/members',{'userId':found[i].id});if(ctx.mounted)Navigator.pop(ctx);_load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.memberAdded)));}catch(_){}
              },
            ))),
      ]);
    }))));
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Padding(padding:EdgeInsets.only(bottom:4),child:Text(s.members+' · ${members.length}',style:TextStyle(color:context.cMut,fontSize:12,fontWeight:FontWeight.w800))),
      if(loading)const Padding(padding:EdgeInsets.all(8),child:CircularProgressIndicator(strokeWidth:2)),
      ...members.take(12).map((m)=>Padding(padding:const EdgeInsets.symmetric(vertical:1),child:InkWell(
        borderRadius:BorderRadius.circular(12),
        onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UserProfilePage(userId:m.id))),
        child:Row(children:[Avatar(name:m.name,size:34),const SizedBox(width:10),Expanded(child:Text(m.name,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,overflow:TextOverflow.ellipsis)))]),
      ))),
      ListTile(leading:const Icon(Icons.person_add_alt_rounded),title:Text(s.addMember),onTap:_add,contentPadding:EdgeInsets.zero),
    ]);
  }
}

// Баннер нового сообщения (реальные уведомления внутри приложения)
class _NotifyBanner extends StatelessWidget{
  final Map<String,dynamic> data;final VoidCallback onTap,onClose;
  const _NotifyBanner({required this.data,required this.onTap,required this.onClose});
  @override Widget build(BuildContext context){
    final name=(data['fromName']??'?').toString();
    final body=(data['body']??'').toString();
    return Material(
      color:context.cSurf,
      borderRadius:BorderRadius.circular(18),
      child:InkWell(
        onTap:onTap,
        borderRadius:BorderRadius.circular(18),
        child:Container(
          padding:const EdgeInsets.fromLTRB(10,10,6,10),
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:context.cLine)),
          child:Row(children:[
            Avatar(name:name,size:42),
            const SizedBox(width:11),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14.5)),
              const SizedBox(height:2),
              Text(body,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:context.cMut,fontSize:12.5)),
            ])),
            IconButton(icon:Icon(Icons.close_rounded,size:18,color:context.cMut),onPressed:onClose),
          ]),
        ),
      ),
    );
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
      decoration:BoxDecoration(color:Theme.of(context).cardTheme.color,borderRadius:BorderRadius.vertical(top:Radius.circular(28)),border:Border(top:BorderSide(color:context.cLine))),
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
                        color:active?purple.withOpacity(.10):context.cSurf2.withOpacity(.6),
                        borderRadius:BorderRadius.circular(18),
                        border:Border.all(color:active?pink.withOpacity(.55):context.cLine),
                        boxShadow:active?[BoxShadow(color:pink.withOpacity(.20),blurRadius:16,offset:const Offset(0,4))]:null,
                      ),
                      child:Column(
                        mainAxisAlignment:MainAxisAlignment.center,
                        children:[
                          Icon(icons[i],size:28,color:active?pink:context.cMut),
                          const SizedBox(height:7),
                          Text(names[i],style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:active?Colors.white:context.cMut)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height:16),
            Text(s.intensity,style:TextStyle(color:context.cMut,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.1)),
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
// ===== Контакты: две вкладки — «Контакты» (сохранённые люди) и «Все люди» (поиск по приложению) =====
class Contacts extends StatefulWidget{
  final void Function(UserX u) onOpenProfile;
  final void Function(Chat c)? onOpenGroup;
  const Contacts({super.key,required this.onOpenProfile,this.onOpenGroup});
  @override State<Contacts> createState()=>_ContactsState();
}
class _ContactsState extends State<Contacts>{
  int seg=0; // 0 = контакты, 1 = все люди
  String q='';bool loading=true;List<UserX> people=[];String? error;
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    if(!mounted)return;setState(()=>loading=true);
    try{
      if(seg==0){
        final a=await Api.get('/contacts');
        people=(a as List).map((x)=>UserX((x['id']??'').toString(),(x['display_name']??'User').toString(),(x['username']??'').toString(),avatar:(x['avatar_url']??'').toString())).toList();
      }else{
        final a=await Api.get('/users?q='+Uri.encodeQueryComponent(q));
        people=(a as List).map((x)=>UserX((x['id']??'').toString(),(x['display_name']??'User').toString(),(x['username']??'').toString(),avatar:(x['avatar_url']??'').toString())).toList();
      }
      error=null;
    }catch(e){people=[];error=e.toString();}
    if(mounted)setState(()=>loading=false);
  }
  List<UserX> get filtered{
    if(seg==0&&q.isNotEmpty){
      final lq=q.toLowerCase();
      return people.where((u)=>u.name.toLowerCase().contains(lq)||u.username.toLowerCase().contains(lq)).toList();
    }
    return people;
  }
  Future<void> _createGroup()async{
    final s=S(context);
    final c=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(s.createGroup),
      content:TextField(controller:c,autofocus:true,decoration:InputDecoration(hintText:s.groupName,filled:true,fillColor:context.cBg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:context.cLine)),isDense:true)),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(s.cancel)),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(s.createGroup)),
      ],
    ));
    if(ok!=true)return;
    final title=c.text.trim();
    if(title.length<2)return;
    try{
      final d=await Api.post('/chats',{'title':title,'isGroup':true});
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.groupCreated)));
      widget.onOpenGroup?.call(Chat((d['id']??'').toString(),title,'','',isGroup:true));
    }catch(_){}
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    final list=filtered;
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,18,20,10),child:Row(children:[Text(s.people,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900,letterSpacing:-.7)),const Spacer(),IconButton(tooltip:s.createGroup,onPressed:()=>_createGroup(),icon:const Icon(Icons.group_add_rounded)),IconButton(tooltip:s.refresh,onPressed:load,icon:const Icon(Icons.refresh_rounded))])),
      // --- Переключатель: Контакты | Все люди (как в Telegram) ---
      Padding(padding:const EdgeInsets.fromLTRB(20,0,20,10),child:Row(children:[
        Expanded(child:_Seg(label:s.tabContacts,active:seg==0,onTap:seg==0?null:(){q='';setState(()=>seg=0);load();})),
        const SizedBox(width:8),
        Expanded(child:_Seg(label:s.tabAllPeople,active:seg==1,onTap:seg==1?null:(){q='';setState(()=>seg=1);load();})),
      ])),
      Padding(
        padding:const EdgeInsets.fromLTRB(20,0,20,2),
        child:_GlassSearchField(hint:seg==0?s.findPeopleHint:s.findPeopleHint,onChanged:(v){q=v.trim();seg==0?setState(() {}):searchDebounced();}),
      ),
      const SizedBox(height:10),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):error!=null?ListView(children:[const SizedBox(height:120),EmptyState(icon:Icons.cloud_off_rounded,title:s.connectionError,sub:error!)]):list.isEmpty?ListView(children:[const SizedBox(height:140),EmptyState(icon:seg==0?Icons.person_add_alt_1_outlined:Icons.person_search_outlined,title:seg==0?s.noContacts:s.noPeople,sub:seg==0?s.noContactsSub:s.noPeopleSub)]):ListView.separated(
        padding:const EdgeInsets.fromLTRB(12,3,12,24),itemCount:list.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
        itemBuilder:(_,i){final u=list[i];return _EntryAnimation(delay:Duration(milliseconds:i>7?320:i*45),child:Material(
          type:MaterialType.transparency,
          child:InkWell(
            borderRadius:BorderRadius.circular(22),
            splashColor:pink.withOpacity(.06),
            highlightColor:pink.withOpacity(.035),
            onTap:()=>widget.onOpenProfile(u),
            child:Container(
              padding:const EdgeInsets.symmetric(horizontal:6,vertical:10),
              decoration:BoxDecoration(
                borderRadius:BorderRadius.circular(22),
                border:Border(bottom:BorderSide(color:context.cLine.withOpacity(.52),width:.7)),
              ),
              child:Row(children:[
                Avatar(name:u.name,size:52,url:u.avatar),const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(u.name,style:const TextStyle(fontWeight:FontWeight.w800)),
                  const SizedBox(height:3),
                  Text('@'+u.username,style:TextStyle(color:context.cMut))
                ])),
                Icon(Icons.arrow_forward_ios_rounded,size:15,color:context.cMut),
              ]),
            ),
          ),
        ));},
      )),
    ]);
  }
  Timer? _deb;
  void searchDebounced(){
    _deb?.cancel();
    _deb=Timer(const Duration(milliseconds:350),(){if(mounted)load();});
  }
}

// Переключатель вкладок внутри Контактов
class _Seg extends StatelessWidget{
  final String label;final bool active;final VoidCallback? onTap;
  const _Seg({required this.label,required this.active,required this.onTap});
  @override Widget build(BuildContext context)=>Material(
    color:active?null:Colors.transparent,
    child:InkWell(
      onTap:onTap,
      borderRadius:BorderRadius.circular(16),
      child:AnimatedContainer(
        duration:const Duration(milliseconds:180),
        height:42,alignment:Alignment.center,
        decoration:BoxDecoration(
          gradient:active?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad):null,
          color:active?null:context.cSurf2.withOpacity(.5),
          borderRadius:BorderRadius.circular(16),
          border:Border.all(color:active?Colors.transparent:context.cLine),
        ),
        child:Text(label,style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:active?Colors.white:context.cMut)),
      ),
    ),
  );
}

class Calls extends StatefulWidget{
  final ValueChanged<Chat> onOpenChat;
  const Calls({super.key,required this.onOpenChat});
  @override State<Calls> createState()=>_CallsState();
}
class _CallsState extends State<Calls>{
  bool loading=true;List<Map<String,dynamic>> list=[];String? error;
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    if(!mounted)return;setState(()=>loading=true);
    try{
      final a=await Api.get('/calls');
      list=(a as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
      error=null;
    }catch(e){error=e.toString();list=[];}
    if(mounted)setState(()=>loading=false);
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,18,20,12),child:Row(children:[Text(s.calls,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900,letterSpacing:-.7)),const Spacer(),IconButton(tooltip:s.refresh,onPressed:load,icon:const Icon(Icons.refresh_rounded))])),
      Expanded(child:loading
        ?const Center(child:CircularProgressIndicator(color:pink))
        :error!=null
          ?ListView(children:[const SizedBox(height:120),EmptyState(icon:Icons.cloud_off_rounded,title:s.connectionError,sub:error!)])
          :list.isEmpty
            ?ListView(children:[const SizedBox(height:140),EmptyState(icon:Icons.call_rounded,title:s.noCalls,sub:s.noCallsSub)])
            :ListView.separated(
              padding:const EdgeInsets.fromLTRB(12,3,12,24),itemCount:list.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
              itemBuilder:(_,i){final c=list[i];
                final dir=(c['direction']??'out').toString();
                final status=(c['status']??'ended').toString();
                final video=c['video']==true;
                final dur=int.tryParse('${c['duration']??0}')??0;
                final name=(c['title']??'?').toString();
                final chatId=(c['chat_id']??'').toString();
                final pav=(c['peer_avatar']??'').toString();
                final Color mark=status=='missed'?pink:(status=='declined'?const Color(0xFFFFB86B):green);
                final IconData ic=dir=='out'?Icons.call_made_rounded:Icons.call_received_rounded;
                final when=shortTime((c['created_at']??'').toString());
                return _EntryAnimation(delay:Duration(milliseconds:i>7?320:i*45),child:Material(
                  type:MaterialType.transparency,
                  child:InkWell(
                    borderRadius:BorderRadius.circular(22),
                    splashColor:pink.withOpacity(.06),
                    onTap:chatId.isEmpty?null:()=>widget.onOpenChat(Chat(chatId,name,'',when)),
                    child:Container(
                      padding:const EdgeInsets.symmetric(horizontal:6,vertical:10),
                      decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),border:Border(bottom:BorderSide(color:context.cLine.withOpacity(.52),width:.7))),
                      child:Row(children:[
                        Avatar(name:name,size:52,url:pav),const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),
                          const SizedBox(height:3),
                          Row(children:[
                            Icon(ic,size:14,color:mark),const SizedBox(width:4),
                            Text(status=='ended'?'${(dur~/60).toString().padLeft(2,'0')}:${(dur%60).toString().padLeft(2,'0')}':(status=='missed'?s.missedCall:s.declined),style:TextStyle(color:context.cMut,fontSize:12.5)),
                            if(video)...[SizedBox(width:6),Icon(Icons.videocam_rounded,size:13,color:context.cMut)],
                            const SizedBox(width:6),
                            Text(when,style:TextStyle(color:context.cMut,fontSize:11)),
                          ]),
                        ])),
                        IconButton(icon:const Icon(Icons.call_outlined,color:green),tooltip:s.voiceCall,onPressed:chatId.isEmpty?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CallPage(call:CallStart(chatId:chatId,name:name,video:false))))),
                      ]),
                    ),
                  ),
                ));},
              )),
    ]);
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

class Settings extends StatefulWidget{
  final String name,username,language;final bool light,notifications;
  final ValueChanged<bool> onTheme,onNotifications;final ValueChanged<String> onLanguage;
  final Future<Map<String,dynamic>> Function(String,String,String?,{String? bio}) onProfile;final VoidCallback onLogout;
  const Settings({super.key,required this.name,required this.username,required this.light,required this.language,required this.notifications,required this.onTheme,required this.onLanguage,required this.onNotifications,required this.onProfile,required this.onLogout});
  @override State<Settings> createState()=>_SettingsState();
}
class _SettingsState extends State<Settings>{
  String avatar='',email='',phone='',bio='';bool emailVerified=false,phoneVerified=false;
  bool meOnline=true,meTyping=true,meReads=true,meShots=false,meCalls=true,secureMode=false;
  @override void initState(){super.initState();_loadMe();}
  Future<void> _loadMe()async{
    try{
      final me=await Api.get('/me');
      if(!mounted)return;
      final so=me['show_online'],st=me['show_typing'],sr=me['show_reads'];
      if(so is bool)gShowOnline=so;
      if(st is bool)gShowTyping=st;
      if(sr is bool)gShowReads=sr;
      final p=await SharedPreferences.getInstance();
      setState((){
        avatar=(me['avatar_url']??'').toString();
        email=(me['email']??'').toString();
        phone=(me['phone']??'').toString();
        bio=(me['bio']??'').toString();
        emailVerified=me['email_verified']==true;
        phoneVerified=me['phone_verified']==true;
        meOnline=gShowOnline;meTyping=gShowTyping;meReads=gShowReads;
        meShots=me['block_screenshots']==true;
        meCalls=me['allow_calls']!=false;
        secureMode=p.getBool('secure_mode')??false;
      });
    }catch(_){}
  }
  void snack(String x)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));
  String _privacySub(AppStrings s)=>[
    meOnline?s.privacyEveryone:s.privacyNobody,
    s.ru?(meShots?'скриншоты чатов: защита':'скриншоты чатов: нет'):(meShots?'chat shots: on':'chat shots: off'),
    s.ru?(meCalls?'звонки: все':'звонки: никто'):(meCalls?'calls: everyone':'calls: nobody'),
  ].join(' · ');
  String _securitySub(AppStrings s)=>[
    gPinOn?(s.ru?'PIN включён':'PIN on'):(s.ru?'PIN выключен':'PIN off'),
    secureMode?(s.ru?'скриншоты запрещены':'shots blocked'):(s.ru?'скриншоты разрешены':'shots allowed'),
  ].join(' · ');

  @override Widget build(BuildContext context){
    final s=S(context);
    return ListView(
      keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
      padding:const EdgeInsets.fromLTRB(18,14,18,110),
      children:[
        const _VibeWordmark(fontSize:28),
        const SizedBox(height:14),
        // --- Шапка-профиль (как в Telegram: ведёт на страницу профиля) ---
        Material(
          color:context.cSurf,
          borderRadius:BorderRadius.circular(24),
          clipBehavior:Clip.antiAlias,
          child:InkWell(
            onTap:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>ProfilePage(name:widget.name,username:widget.username,avatar:avatar,email:email,onProfile:widget.onProfile)));if(mounted)_loadMe();},
            child:Padding(
              padding:const EdgeInsets.all(13),
              child:Row(children:[
                Avatar(name:widget.name,size:64,url:avatar),
                const SizedBox(width:14),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(widget.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:17.5,fontWeight:FontWeight.w900)),
                  const SizedBox(height:3),
                  Row(children:[
                    Flexible(child:Text('@'+widget.username,style:TextStyle(color:context.cMut,fontSize:13),overflow:TextOverflow.ellipsis)),
                    if(emailVerified)...[const SizedBox(width:5),Icon(Icons.verified_rounded,size:14,color:green)],
                    if(phoneVerified)...[const SizedBox(width:3),Icon(Icons.verified_user_rounded,size:13,color:green)],
                  ]),
                  const SizedBox(height:3),
                  Text(bio.isNotEmpty?bio:s.profileTagline,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:bio.isNotEmpty?context.cMut:purple,fontSize:12,fontWeight:bio.isNotEmpty?FontWeight.w600:FontWeight.w700)),
                ])),
                Icon(Icons.arrow_forward_ios_rounded,size:16,color:context.cMut),
              ]),
            ),
          ),
        ),
        _VibeGroup(children:[
          ListTile(
            leading:_IconBadge(icon:Icons.notifications_none_rounded,color:pink),
            title:Text(s.notifications,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(widget.notifications?s.notificationsOn:s.notificationsOff,style:TextStyle(color:context.cMut,fontSize:12)),
            trailing:Switch(value:widget.notifications,onChanged:widget.onNotifications),
          ),
        ]),
        _VibeGroup(title:s.appearance,children:[
          ListTile(
            leading:_IconBadge(icon:Icons.dark_mode_outlined,color:purple),
            title:Text(s.themePick,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(widget.light?s.themeLight:s.themeDark,style:TextStyle(color:context.cMut,fontSize:12)),
            trailing:Icon(Icons.chevron_right_rounded,color:context.cMut),
            onTap:themeSheet,
          ),
          ListTile(
            leading:_IconBadge(icon:Icons.translate_rounded,color:blue),
            title:Text(s.language,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(widget.language=='ru'?s.russian:s.english,style:TextStyle(color:context.cMut,fontSize:12)),
            trailing:Icon(Icons.chevron_right_rounded,color:context.cMut),
            onTap:()=>languagePicker(context),
          ),
        ]),
        _VibeGroup(title:s.privacy,children:[
          ListTile(
            leading:_IconBadge(icon:Icons.visibility_outlined,color:green),
            title:Text(s.privacy,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(_privacySub(s),style:TextStyle(color:context.cMut,fontSize:12)),
            trailing:Icon(Icons.chevron_right_rounded,color:context.cMut),
            onTap:()async{
              await Navigator.push(context,MaterialPageRoute(builder:(_)=>PrivacyPage(name:widget.name,username:widget.username)));
              if(mounted)_loadMe();
            },
          ),
        ]),
        _VibeGroup(title:s.security,children:[
          ListTile(
            leading:_IconBadge(icon:Icons.shield_outlined,color:pink),
            title:Text(s.security,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(_securitySub(s),style:TextStyle(color:context.cMut,fontSize:12)),
            trailing:Icon(Icons.chevron_right_rounded,color:context.cMut),
            onTap:()async{
              await Navigator.push(context,MaterialPageRoute(builder:(_)=>const SecurityPage()));
              if(mounted)_loadMe();
            },
          ),
        ]),
        _VibeGroup(title:s.about,children:[
          ListTile(
            leading:_IconBadge(icon:Icons.info_outline_rounded,color:purple),
            title:Text(s.about,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(s.version,style:TextStyle(color:context.cMut,fontSize:12)),
            trailing:Icon(Icons.chevron_right_rounded,color:context.cMut),
            onTap:()=>info(context,'vibe<3',s.aboutBody),
          ),
        ]),
        const SizedBox(height:18),
        OutlinedButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout_rounded),label:Text(s.signOut),style:OutlinedButton.styleFrom(foregroundColor:pink,side:const BorderSide(color:pink),minimumSize:const Size.fromHeight(52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),
      ],
    );
  }
  // ===== Выбор темы: тап по уже выбранной НИЧЕГО не делает, выбор применяется мгновенно =====
  void themeSheet(){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(
      padding:const EdgeInsets.fromLTRB(20,8,20,26),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(s.themePick,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
        const SizedBox(height:3),
        Text(s.themeSystemHint,style:TextStyle(color:context.cMut,fontSize:12)),
        const SizedBox(height:14),
        Row(children:[
          Expanded(child:_ThemeCard(dark:true,selected:!widget.light,label:s.themeDark,onTap:(!widget.light)?null:()=>widget.onTheme(false))),
          const SizedBox(width:10),
          Expanded(child:_ThemeCard(dark:false,selected:widget.light,label:s.themeLight,onTap:widget.light?null:()=>widget.onTheme(true))),
        ]),
      ]),
    )));
  }
  void languagePicker(BuildContext context){
    final s=S(context);
    showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,8,20,4),child:Text(s.chooseLanguage,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900))),
      ListTile(leading:const Text('🇷🇺',style:TextStyle(fontSize:24)),title:Text(s.russian),trailing:widget.language=='ru'?const Icon(Icons.check_rounded,color:pink):null,onTap:(){Navigator.pop(context);widget.onLanguage('ru');}),
      ListTile(leading:const Text('🇺🇸',style:TextStyle(fontSize:24)),title:Text(s.english),trailing:widget.language=='en'?const Icon(Icons.check_rounded,color:pink):null,onTap:(){Navigator.pop(context);widget.onLanguage('en');}),
      const SizedBox(height:12),
    ])));
  }
  void info(BuildContext context,String title,String body)=>showDialog(context:context,builder:(_)=>AlertDialog(title:Text(title),content:Text(body),actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:Text(S(context).ok))]));
}

// ===== Страница профиля (как в Telegram): шапка-градиент, большой аватар, инфо, действия =====
// ===== Профиль другого человека (Telegram-стиль): шапка, статус, bio, действия =====
class UserProfilePage extends StatefulWidget{
  final String userId;
  final Future<void> Function(UserX u)? onMessage;
  final Future<void> Function(UserX u,bool video)? onCall;
  const UserProfilePage({super.key,required this.userId,this.onMessage,this.onCall});
  @override State<UserProfilePage> createState()=>_UserProfilePageState();
}
class _UserProfilePageState extends State<UserProfilePage>{
  bool loading=true;String? error;
  String name='',username='',avatar='',bio='',phone='';
  bool isContact=false,online=false,onlineHidden=false;DateTime? lastSeen;
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    try{
      final d=await Api.get('/users/'+widget.userId);
      if(!mounted)return;
      setState((){
        name=(d['display_name']??'').toString();
        username=(d['username']??'').toString();
        avatar=(d['avatar_url']??'').toString();
        bio=(d['bio']??'').toString();
        phone=(d['phone']??'').toString();
        isContact=d['isContact']==true;
        online=d['online']==true;
        onlineHidden=d['online']==null;
        lastSeen=d['lastSeen']!=null?DateTime.tryParse(d['lastSeen'].toString()):null;
        error=null;loading=false;
      });
    }catch(e){if(mounted)setState(() {error=e.toString();loading=false;});}
  }
  void snack(String x)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));
  Future<void> toggleContact()async{
    final s=S(context);
    try{
      if(isContact){await Api.delete('/contacts/'+widget.userId);}
      else{await Api.post('/contacts',{'userId':widget.userId});}
      if(!mounted)return;
      setState(()=>isContact=!isContact);
      snack(isContact?s.contactAdded:s.contactRemoved);
    }catch(e){snack(S(context).connectionError);}
  }
  void copy(String v,String label){
    Clipboard.setData(ClipboardData(text:v));
    snack(label+': '+S(context).copied);
  }
  String _status(AppStrings s){
    if(onlineHidden)return s.active;
    if(online)return s.online;
    if(lastSeen!=null){
      final diff=DateTime.now().difference(lastSeen!);
      return diff.inHours<24?s.lastSeenRecent:s.lastSeenLong;
    }
    return s.active;
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(error!=null)return Scaffold(body:ListView(children:[const SizedBox(height:160),EmptyState(icon:Icons.person_off_outlined,title:s.connectionError,sub:error!)]));
    final statusColor=online&&!onlineHidden?green:(onlineHidden?context.cMut:purple);
    return Scaffold(
      body:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        // --- градиентная шапка ---
        Stack(clipBehavior:Clip.none,children:[
          Container(height:170,decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad))),
          Positioned(top:-60,right:-50,child:_Glow(size:200,color:Colors.white.withOpacity(.16))),
          SafeArea(child:SizedBox(height:56,child:Row(children:[
            const SizedBox(width:6),
            SizedBox(width:44,height:44,child:IconButton(tooltip:'Назад',onPressed:()=>Navigator.maybePop(context),icon:const Icon(Icons.arrow_back_rounded,color:Colors.white))),
            const Spacer(),
          ]))),
          Positioned(left:0,right:0,bottom:-55,child:Center(child:Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:context.cBg,shape:BoxShape.circle),child:Avatar(name:name,size:110,url:avatar)))),
        ]),
        const SizedBox(height:66),
        Text(name,textAlign:TextAlign.center,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,letterSpacing:-.5)),
        const SizedBox(height:4),
        Text('@'+username,textAlign:TextAlign.center,style:TextStyle(color:context.cMut,fontSize:14)),
        const SizedBox(height:6),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(width:7,height:7,decoration:BoxDecoration(color:statusColor,shape:BoxShape.circle)),
          const SizedBox(width:6),
          Text(_status(s),style:TextStyle(color:statusColor,fontSize:12.5,fontWeight:FontWeight.w800)),
        ]),
        const SizedBox(height:22),
        Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(bio.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:6),child:Row(children:[
            const SizedBox(width:2),
            Expanded(child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),decoration:BoxDecoration(color:context.cSurf,borderRadius:BorderRadius.circular(20),border:Border.all(color:context.cLine)),child:Text(bio,style:const TextStyle(fontSize:14,height:1.4)))),
          ])),
          _VibeGroup(children:[
            ListTile(
              leading:_IconBadge(icon:Icons.alternate_email_rounded,color:purple),
              title:Text('@'+username,style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text(s.usernameLabel,style:TextStyle(color:context.cMut,fontSize:12)),
              trailing:Icon(Icons.copy_rounded,size:18,color:context.cMut),
              onTap:()=>copy('@'+username,s.usernameLabel),
            ),
            if(phone.isNotEmpty)ListTile(
              leading:_IconBadge(icon:Icons.call_outlined,color:green),
              title:Text(phone,style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text(s.phoneLabel,style:TextStyle(color:context.cMut,fontSize:12)),
              trailing:Icon(Icons.copy_rounded,size:18,color:context.cMut),
              onTap:()=>copy(phone,s.phoneLabel),
            ),
          ]),
          const SizedBox(height:16),
          Row(children:[
            Expanded(child:_GradientButton(height:52,radius:16,icon:Icons.chat_bubble_outline_rounded,label:s.writeMsg,busy:false,onTap:()=>widget.onMessage?.call(UserX(widget.userId,name,username,avatar:avatar)))),
            const SizedBox(width:10),
            SizedBox(width:52,height:52,child:OutlinedButton(onPressed:()=>widget.onCall?.call(UserX(widget.userId,name,username,avatar:avatar),false),style:OutlinedButton.styleFrom(padding:EdgeInsets.zero,side:const BorderSide(color:purple),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:const Icon(Icons.call_outlined,color:purple))),
          ]),
          const SizedBox(height:10),
          OutlinedButton.icon(
            onPressed:toggleContact,
            style:OutlinedButton.styleFrom(foregroundColor:isContact?pink:green,side:BorderSide(color:isContact?pink:green),minimumSize:const Size.fromHeight(50),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
            icon:Icon(isContact?Icons.person_remove_outlined:Icons.person_add_alt_1_outlined,size:19),
            label:Text(isContact?s.removeContact:s.addContact),
          ),
          const SizedBox(height:24),
        ])),
      ])),
    );
  }
}

// ===== Мой профиль: крупная шапка, био, бейджи подтверждения (Telegram-стиль, но круче) =====
class ProfilePage extends StatefulWidget{
  final String name,username,avatar,email;
  final Future<Map<String,dynamic>> Function(String,String,String?,{String? bio}) onProfile;
  const ProfilePage({super.key,required this.name,required this.username,required this.avatar,required this.email,required this.onProfile});
  @override State<ProfilePage> createState()=>_ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage>{
  late String name,username,avatar;String email='',phone='',bio='';
  bool emailVerified=false,phoneVerified=false;
  @override void initState(){super.initState();name=widget.name;username=widget.username;avatar=widget.avatar;_load();}
  Future<void> _load()async{
    try{
      final me=await Api.get('/me');
      if(!mounted)return;
      setState((){
        avatar=(me['avatar_url']??'').toString();
        email=(me['email']??'').toString();
        phone=(me['phone']??'').toString();
        bio=(me['bio']??'').toString();
        emailVerified=me['email_verified']==true;
        phoneVerified=me['phone_verified']==true;
      });
    }catch(_){}
  }
  void snack(String x)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));
  Future<void> _photoSheet()async{
    final s=S(context);
    final src=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.photo_camera_outlined),title:Text(s.cameraShot),onTap:()=>Navigator.pop(context,'camera')),
      ListTile(leading:const Icon(Icons.photo_outlined),title:Text(s.fromGallery),onTap:()=>Navigator.pop(context,'gallery')),
      if(avatar.isNotEmpty)
        ListTile(leading:const Icon(Icons.delete_outline_rounded),title:Text(s.removePhoto),onTap:()=>Navigator.pop(context,'remove')),
    ])));
    if(src==null)return;
    if(src=='remove'){
      try{
        await widget.onProfile(name,username,'');
        if(mounted)setState(()=>avatar='');
        snack(s.photoUpdated);
      }catch(_){snack(s.mediaFailed);}
      return;
    }
    try{
      final x=await ImagePicker().pickImage(source:src=='camera'?ImageSource.camera:ImageSource.gallery,maxWidth:512,maxHeight:512,imageQuality:82);
      if(x==null)return;
      final b=await x.readAsBytes();
      final data='data:image/jpeg;base64,'+base64Encode(b);
      if(data.length>500000){snack(s.photoTooBig);return;}
      final resp=await widget.onProfile(name,username,data);
      if(mounted)setState(()=>avatar=(resp['avatar_url']??data).toString());
      snack(s.photoUpdated);
    }catch(_){if(mounted)snack(s.mediaFailed);}
  }
  Future<void> _openEditor()async{
    final resp=await Navigator.push<Map>(context,MaterialPageRoute(builder:(_)=>EditProfilePage(name:name,username:username,avatar:avatar,bio:bio,onProfile:widget.onProfile)));
    if(resp!=null){
      setState((){
        name=(resp['name']??name).toString();
        username=(resp['username']??username).toString();
        avatar=(resp['avatar_url']??avatar).toString();
        bio=(resp['bio']??bio).toString();
      });
      _load();
    }
  }
  // Подтверждение почты/телефона для существующего аккаунта: запрос кода → ввод → флаг на сервере
  Future<void> _verify(String purpose)async{
    final s=S(context);
    final target=purpose=='phone'?phone:email;
    if(target.isEmpty){snack(s.ru?'Сначала укажи цель подтверждения':'Nothing to verify');return;}
    final ok=await _codeDialog(purpose,target);
    if(ok&&mounted){
      snack(purpose=='phone'?s.phoneVerifiedOk:s.emailVerifiedOk);
      _load();
    }
  }
  // Диалог ввода кода — общий для подтверждения и добавления телефона
  Future<bool> _codeDialog(String purpose,String target)async{
    final s=S(context);
    String? dev;final ctl=TextEditingController();bool busy=false;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      backgroundColor:context.cSurf,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
      title:Row(children:[Icon(purpose=='phone'?Icons.call_outlined:Icons.mark_email_unread_outlined,size:20,color:purpose=='phone'?purple:pink),const SizedBox(width:8),Expanded(child:Text(purpose=='phone'?s.verifyPhoneTitle:s.verifyEmailTitle,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)))]),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text((purpose=='phone'?s.regCodeSentPhone:s.regCodeSentEmail)+' '+target,style:TextStyle(color:context.cMut,fontSize:12.5)),
        const SizedBox(height:14),
        TextField(controller:ctl,enabled:!busy,autofocus:true,maxLength:6,keyboardType:TextInputType.number,textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,letterSpacing:10),decoration:InputDecoration(hintText:'——',counterText:'',filled:true,fillColor:context.cBg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide(color:context.cLine)))),
        if(dev!=null)...[
          const SizedBox(height:10),
          Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:purple.withOpacity(.10),borderRadius:BorderRadius.circular(12),border:Border.all(color:purple.withOpacity(.35))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(s.regCodeDevNote,style:TextStyle(color:context.cMut,fontSize:10.5,height:1.3)),
            const SizedBox(height:5),
            Text('Код: $dev',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,letterSpacing:2,color:purple)),
          ])),
        ],
      ]),
      actions:[
        TextButton(onPressed:busy?null:()async{
          setD(()=>busy=true);
          try{final d=await Api.post('/auth/request-code',{'purpose':purpose,'target':target});setD(() {dev=(d['devCode']??'').toString().isEmpty?null:(d['devCode']??'').toString();if(dev!=null)ctl.text=dev!;});}
          catch(e){if(ctx.mounted)Navigator.pop(ctx);snack(friendlyError(e,s));return;}
          setD(()=>busy=false);
        },child:Text(dev==null?s.regCodeTitle:s.regCodeResend)),
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(s.cancel)),
        FilledButton(onPressed:busy?null:()async{
          final c=ctl.text.trim();
          if(c.length!=6){snack(s.codeInvalid);return;}
          setD(()=>busy=true);
          try{
            await Api.post('/auth/verify-code',{'purpose':purpose,'target':target,'code':c});
            if(ctx.mounted)Navigator.pop(ctx,true);
          }catch(e){snack(friendlyError(e,s));setD(()=>busy=false);}
        },child:Text(s.regVerify)),
      ],
    )));
    return ok==true;
  }
  // v1.3.1: добавить телефон (аккаунты, созданные до v1.3.0): номер → код → сервер ставит phone+phone_verified
  Future<void> _addPhone()async{
    final s=S(context);
    final ctl=TextEditingController();
    final raw=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:context.cSurf,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
      title:Row(children:[const Icon(Icons.call_outlined,size:20,color:green),const SizedBox(width:8),Expanded(child:Text(s.addPhone,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)))]),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(s.regPhoneSub,style:TextStyle(color:context.cMut,fontSize:12.5)),
        const SizedBox(height:12),
        TextField(controller:ctl,autofocus:true,keyboardType:TextInputType.phone,textInputAction:TextInputAction.done,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800),decoration:InputDecoration(hintText:s.regPhoneHint,filled:true,fillColor:context.cBg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide(color:context.cLine)))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(s.cancel)),
        FilledButton(onPressed:()=>Navigator.pop(ctx,ctl.text.trim()),child:Text(s.getCode)),
      ],
    ));
    if(raw==null)return;
    final digits=raw.replaceAll(RegExp(r'[^\d+]'),'');
    if(digits.replaceFirst('+','').length<7){snack(s.ru?'Проверь номер телефона':'Check the phone number');return;}
    final ok=await _codeDialog('phone',digits);
    if(!ok)return;
    try{
      await Api.put('/me/phone',{'phone':digits});
      if(mounted){snack(s.phoneAdded);_load();}
    }catch(e){snack(friendlyError(e,s));}
  }
  Widget _badge(AppStrings s,{required bool ok,required String label,required Color color,required IconData icon,VoidCallback? onTap})=>InkWell(
    onTap:onTap,
    borderRadius:BorderRadius.circular(999),
    child:Container(
      padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
      decoration:BoxDecoration(color:color.withOpacity(ok?0.13:0.09),borderRadius:BorderRadius.circular(999),border:Border.all(color:color.withOpacity(ok?0.55:0.35))),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(ok?Icons.verified_rounded:Icons.error_outline_rounded,size:14,color:color),
        const SizedBox(width:5),
        Text(label,style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w800)),
      ]),
    ),
  );
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(
      body:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        // --- градиентная шапка с аватаром ---
        Stack(clipBehavior:Clip.none,children:[
          Container(height:190,decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad))),
          Positioned(top:-50,left:-60,child:_Glow(size:180,color:Colors.white.withOpacity(.15))),
          Positioned(top:30,right:-70,child:_Glow(size:200,color:Colors.white.withOpacity(.10))),
          SafeArea(
            child:SizedBox(
              height:56,
              child:Row(children:[
                const SizedBox(width:6),
                SizedBox(width:44,height:44,child:IconButton(tooltip:'Назад',onPressed:()=>Navigator.maybePop(context),icon:const Icon(Icons.arrow_back_rounded,color:Colors.white))),
                const Spacer(),
                Padding(padding:const EdgeInsets.only(right:12),child:Text(s.profileTitle,style:TextStyle(color:Colors.white.withOpacity(.9),fontSize:15,fontWeight:FontWeight.w900))),
              ]),
            ),
          ),
          Positioned(left:0,right:0,bottom:-58,child:Center(child:GestureDetector(
            onTap:_photoSheet,
            child:Stack(clipBehavior:Clip.none,children:[
              Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:context.cBg,shape:BoxShape.circle),child:Avatar(name:name,size:112,url:avatar)),
              Positioned(right:2,bottom:2,child:Container(
                width:34,height:34,
                decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),shape:BoxShape.circle,border:Border.all(color:context.cBg,width:3)),
                child:const Icon(Icons.photo_camera_rounded,size:15,color:Colors.white),
              )),
            ]),
          ))),
        ]),
        const SizedBox(height:68),
        Text(name,textAlign:TextAlign.center,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900,letterSpacing:-.5)),
        const SizedBox(height:4),
        Text('@'+username,textAlign:TextAlign.center,style:TextStyle(color:context.cMut,fontSize:14)),
        if(bio.isNotEmpty)...[
          const SizedBox(height:8),
          Padding(padding:const EdgeInsets.symmetric(horizontal:34),child:Text(bio,textAlign:TextAlign.center,style:const TextStyle(fontSize:13.5,height:1.4))),
        ],
        const SizedBox(height:14),
        // --- бейджи подтверждения почты и телефона ---
        Padding(padding:const EdgeInsets.symmetric(horizontal:22),child:Wrap(alignment:WrapAlignment.center,spacing:8,runSpacing:8,children:[
          _badge(s,ok:emailVerified,label:(emailVerified?s.verifiedBadge:s.unverifiedBadge)+' · '+s.emailLabel,color:emailVerified?green:pink,icon:Icons.mail_outline_rounded,onTap:emailVerified?null:()=>_verify('email')),
          if(phone.isNotEmpty)_badge(s,ok:phoneVerified,label:(phoneVerified?s.verifiedBadge:s.unverifiedBadge)+' · '+s.phoneLabel,color:phoneVerified?green:pink,icon:Icons.call_outlined,onTap:phoneVerified?null:()=>_verify('phone')),
        ])),
        const SizedBox(height:22),
        Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          _VibeGroup(children:[
            ListTile(
              leading:_IconBadge(icon:Icons.alternate_email_rounded,color:purple),
              title:Text('@'+username,style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text(s.usernameLabel,style:TextStyle(color:context.cMut,fontSize:12)),
            ),
            ListTile(
              leading:_IconBadge(icon:Icons.mail_outline_rounded,color:blue),
              title:Text(email.isEmpty?'—':email,style:const TextStyle(fontWeight:FontWeight.w700),maxLines:1,overflow:TextOverflow.ellipsis),
              subtitle:Text(s.emailLabel+(emailVerified?' · '+s.verifiedBadge:''),style:TextStyle(color:context.cMut,fontSize:12)),
              trailing:emailVerified?Icon(Icons.verified_rounded,size:19,color:green):(TextButton(onPressed:()=>_verify('email'),child:Text(s.verifyEmailTitle,style:const TextStyle(fontSize:11)))),
            ),
            if(phone.isEmpty)ListTile(
              leading:_IconBadge(icon:Icons.call_outlined,color:green),
              title:Text(s.addPhone,style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text(s.phoneLabel,style:TextStyle(color:context.cMut,fontSize:12)),
              trailing:Icon(Icons.add_circle_outline_rounded,color:green),
              onTap:_addPhone,
            ),
            if(phone.isNotEmpty)ListTile(
              leading:_IconBadge(icon:Icons.call_outlined,color:green),
              title:Text(phone,style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text(s.phoneLabel+(phoneVerified?' · '+s.verifiedBadge:''),style:TextStyle(color:context.cMut,fontSize:12)),
              trailing:phoneVerified?Icon(Icons.verified_rounded,size:19,color:green):(TextButton(onPressed:()=>_verify('phone'),child:Text(s.verifyPhoneTitle,style:const TextStyle(fontSize:11)))),
            ),
          ]),
          const SizedBox(height:6),
          _GradientButton(height:52,radius:16,icon:Icons.edit_rounded,label:s.editProfile,busy:false,onTap:_openEditor),
          const SizedBox(height:20),
        ])),
      ])),
    );
  }
}

// ===== Редактор профиля (полноэкранный, как в Telegram) =====
class EditProfilePage extends StatefulWidget{
  final String name,username,avatar,bio;
  final Future<Map<String,dynamic>> Function(String,String,String?,{String? bio}) onProfile;
  const EditProfilePage({super.key,required this.name,required this.username,required this.avatar,required this.bio,required this.onProfile});
  @override State<EditProfilePage> createState()=>_EditProfilePageState();
}
class _EditProfilePageState extends State<EditProfilePage>{
  late final TextEditingController n=TextEditingController(text:widget.name);
  late final TextEditingController u=TextEditingController(text:widget.username);
  late final TextEditingController b=TextEditingController(text:widget.bio);
  String? pending; // null = не менял, '' = удалить фото, dataURL = новое фото
  bool busy=false;
  @override void dispose(){n.dispose();u.dispose();b.dispose();super.dispose();}
  void snack(String x)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));
  String get curAvatar=>pending==null?widget.avatar:pending!;
  bool get hasPendingRemove=>pending!=null&&pending!.isEmpty;
  Future<void> _pickPhoto()async{
    final s=S(context);
    final src=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.photo_camera_outlined),title:Text(s.cameraShot),onTap:()=>Navigator.pop(context,'camera')),
      ListTile(leading:const Icon(Icons.photo_outlined),title:Text(s.fromGallery),onTap:()=>Navigator.pop(context,'gallery')),
      if(widget.avatar.isNotEmpty||hasPendingRemove||(pending!=null&&pending!.isNotEmpty))
        ListTile(leading:const Icon(Icons.delete_outline_rounded),title:Text(s.removePhoto),onTap:()=>Navigator.pop(context,'remove')),
    ])));
    if(src==null)return;
    if(src=='remove'){setState(()=>pending='');return;}
    try{
      final x=await ImagePicker().pickImage(source:src=='camera'?ImageSource.camera:ImageSource.gallery,maxWidth:512,maxHeight:512,imageQuality:82);
      if(x==null)return;
      final b=await x.readAsBytes();
      final data='data:image/jpeg;base64,'+base64Encode(b);
      if(data.length>500000){snack(s.photoTooBig);return;}
      setState(()=>pending=data);
    }catch(_){snack(s.mediaFailed);}
  }
  Future<void> _save()async{
    final s=S(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final nn=n.text.trim();final uu=u.text.trim().toLowerCase().replaceFirst('@','');final bb=b.text.trim();
    if(nn.length<2||!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(uu)){snack(s.profileCheck);return;}
    setState(()=>busy=true);
    try{
      final resp=await widget.onProfile(nn,uu,pending,bio:bb);
      final out=Map<String,dynamic>.from(resp);
      out['name']=nn;out['username']=uu;out['bio']=bb;
      if(mounted)Navigator.pop(context,out);
    }catch(e){
      setState(()=>busy=false);
      final x=e.toString();
      snack(x.contains('username_taken')?s.usernameTaken:(x.contains('invalid_avatar')?s.photoTooBig:s.profileSaveError));
    }
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(
      appBar:AppBar(
        title:Text(s.editProfile,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
        centerTitle:false,
      ),
      body:ListView(
        keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
        padding:const EdgeInsets.fromLTRB(24,10,24,30),
        children:[
          const SizedBox(height:8),
          Center(child:_AvatarPicker(name:n.text.isEmpty?widget.name:n.text,url:curAvatar,onTap:_pickPhoto)),
          const SizedBox(height:26),
          Text(s.name.toUpperCase(),style:TextStyle(color:context.cMut,fontSize:10.5,fontWeight:FontWeight.w900,letterSpacing:1.2)),
          const SizedBox(height:6),
          _BareField(controller:n,hint:s.nameHint),
          const SizedBox(height:20),
          Text(s.usernameLabel.toUpperCase(),style:TextStyle(color:context.cMut,fontSize:10.5,fontWeight:FontWeight.w900,letterSpacing:1.2)),
          const SizedBox(height:6),
          Row(children:[Text('@',style:TextStyle(color:context.cMut,fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(width:2),Expanded(child:_BareField(controller:u,hint:s.usernameHint))]),
          const SizedBox(height:7),
          Align(alignment:Alignment.centerLeft,child:Text(s.usernameRules,style:TextStyle(color:context.cMut,fontSize:11))),
          const SizedBox(height:20),
          Text(s.aboutBio.toUpperCase(),style:TextStyle(color:context.cMut,fontSize:10.5,fontWeight:FontWeight.w900,letterSpacing:1.2)),
          const SizedBox(height:6),
          _BareField(controller:b,hint:s.bioEditHint,maxLines:2,maxLength:160),
          const SizedBox(height:10),
          _GradientButton(height:54,radius:16,busy:busy,icon:Icons.check_rounded,label:s.saveChanges,onTap:_save),
          const SizedBox(height:4),
          TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:Text(s.cancel)),
        ],
      ),
    );
  }
}

// ===== Приватность (полноэкранная, как в Telegram): живые тумблеры, всё на сервере =====
class PrivacyPage extends StatefulWidget{
  final String name,username;
  const PrivacyPage({super.key,required this.name,required this.username});
  @override State<PrivacyPage> createState()=>_PrivacyPageState();
}
class _PrivacyPageState extends State<PrivacyPage>{
  bool loading=true,online=true,typing=true,reads=true,shots=false,calls=true,hidePrev=gHidePreviews;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final me=await Api.get('/me');
      if(!mounted)return;
      setState((){
        online=me['show_online']!=false;
        typing=me['show_typing']!=false;
        reads=me['show_reads']!=false;
        shots=me['block_screenshots']==true;
        calls=me['allow_calls']!=false;
        loading=false;
        gShowOnline=online;gShowTyping=typing;gShowReads=reads;
      });
    }catch(_){if(mounted)setState(()=>loading=false);}
  }
  Future<void> _put(Map<String,dynamic> flags)async{
    try{await Api.put('/me',{'name':widget.name,'username':widget.username,...flags});}catch(_){}
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return _SubScaffold(
      title:s.privacy,
      subtitle:s.privacyRealSub,
      child:loading
        ?const Center(child:CircularProgressIndicator())
        :ListView(
          padding:const EdgeInsets.fromLTRB(18,4,18,110),
          children:[
            _VibeGroup(title:s.privacySectionVisibility,children:[
              Padding(
                padding:const EdgeInsets.fromLTRB(16,12,16,4),
                child:Text(s.privacyWhoOnline,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:14.5)),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(16,8,16,6),
                child:Row(children:[
                  Expanded(child:_ChoiceChip(label:s.privacyEveryone,active:online,onTap:(){setState(()=>online=true);gShowOnline=true;_put({'showOnline':true});})),
                  const SizedBox(width:10),
                  Expanded(child:_ChoiceChip(label:s.privacyNobody,active:!online,onTap:(){setState(()=>online=false);gShowOnline=false;_put({'showOnline':false});})),
                ]),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(16,0,16,12),
                child:Text(s.privacyWhoOnlineSub,style:TextStyle(color:context.cMut,fontSize:11.5,height:1.35)),
              ),
              SwitchListTile(
                contentPadding:const EdgeInsets.symmetric(horizontal:16),
                secondary:_IconBadge(icon:Icons.keyboard_rounded,color:pink),
                value:typing,
                title:Text(s.showTyping,style:const TextStyle(fontWeight:FontWeight.w700)),
                onChanged:(v){setState(()=>typing=v);gShowTyping=v;_put({'showTyping':v});},
              ),
              SwitchListTile(
                contentPadding:const EdgeInsets.fromLTRB(16,0,16,8),
                secondary:_IconBadge(icon:Icons.done_all_rounded,color:green),
                value:reads,
                title:Text(s.showReads,style:const TextStyle(fontWeight:FontWeight.w700)),
                subtitle:Text(s.showReadsSub,style:TextStyle(color:context.cMut,fontSize:12)),
                onChanged:(v){setState(()=>reads=v);gShowReads=v;_put({'showReads':v});},
              ),
            ]),
            _VibeGroup(title:s.privacySectionChats,children:[
              SwitchListTile(
                contentPadding:const EdgeInsets.fromLTRB(16,8,16,4),
                secondary:_IconBadge(icon:Icons.screenshot_monitor_outlined,color:purple),
                value:shots,
                title:Text(s.privacyShotsMine,style:const TextStyle(fontWeight:FontWeight.w700)),
                subtitle:Text(s.privacyShotsMineSub,style:TextStyle(color:context.cMut,fontSize:12)),
                onChanged:(v){setState(()=>shots=v);_put({'blockScreenshots':v});},
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(16,12,16,4),
                child:Text(s.privacyWhoCalls,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:14.5)),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(16,8,16,6),
                child:Row(children:[
                  Expanded(child:_ChoiceChip(label:s.privacyEveryone,active:calls,onTap:(){setState(()=>calls=true);_put({'allowCalls':true});})),
                  const SizedBox(width:10),
                  Expanded(child:_ChoiceChip(label:s.privacyNobody,active:!calls,onTap:(){setState(()=>calls=false);_put({'allowCalls':false});})),
                ]),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(16,0,16,12),
                child:Text(s.privacyWhoCallsSub,style:TextStyle(color:context.cMut,fontSize:11.5,height:1.35)),
              ),
              SwitchListTile(
                contentPadding:const EdgeInsets.fromLTRB(16,0,16,12),
                secondary:_IconBadge(icon:Icons.hide_source_rounded,color:blue),
                value:hidePrev,
                title:Text(s.hidePreviews,style:const TextStyle(fontWeight:FontWeight.w700)),
                subtitle:Text(s.hidePreviewsSub,style:TextStyle(color:context.cMut,fontSize:12)),
                onChanged:(v)async{setState(()=>hidePrev=v);gHidePreviews=v;final p=await SharedPreferences.getInstance();await p.setBool('hide_previews',v);chatsChanged.value++;},
              ),
            ]),
            const SizedBox(height:8),
            Padding(
              padding:const EdgeInsets.symmetric(horizontal:6),
              child:Text(s.privacyBody,style:TextStyle(color:context.cMut,fontSize:12,height:1.45)),
            ),
          ],
        ),
    );
  }
}

// ===== Безопасность (полноэкранная): PIN + запрет скриншотов, тумблер срабатывает МГНОВЕННО =====
class SecurityPage extends StatefulWidget{
  const SecurityPage({super.key});
  @override State<SecurityPage> createState()=>_SecurityPageState();
}
class _SecurityPageState extends State<SecurityPage>{
  bool pinOn=false,pinBg=false,secure=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    final p=await SharedPreferences.getInstance();
    if(!mounted)return;
    setState((){
      pinOn=p.getString('pin_hash')!=null;
      gPinOn=pinOn;
      pinBg=p.getBool('pin_bg')??false;
      gPinBg=pinBg;
      secure=p.getBool('secure_mode')??false;
    });
  }
  void snack(String x)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));
  Future<String?> _askPin(String title)=>Navigator.push<String>(context,MaterialPageRoute(fullscreenDialog:true,builder:(_)=>_PinScreen(title:title,popOnSuccess:true,onEnter:(pin)async=>true)));
  Future<bool> _verifyPin(String pin)async{final p=await SharedPreferences.getInstance();return pinHash(pin)==(p.getString('pin_hash')??'');}
  Future<void> _setPin(String pin)async{final p=await SharedPreferences.getInstance();await p.setString('pin_hash',pinHash(pin));gPinOn=true;}
  Future<void> _togglePin(bool want)async{
    final s=S(context);
    if(want){
      final p1=await _askPin(s.pinCreate);if(p1==null)return;
      final p2=await _askPin(s.pinRepeat);if(p2==null)return;
      if(p1!=p2){snack(s.pinMismatch);return;}
      await _setPin(p1);
    }else{
      final old=await _askPin(s.pinEnter);if(old==null)return;
      if(!await _verifyPin(old)){snack(s.pinWrong);return;}
      final p=await SharedPreferences.getInstance();await p.remove('pin_hash');gPinOn=false;
    }
    if(mounted)setState(()=>pinOn=gPinOn);
  }
  Future<void> _changePin()async{
    final s=S(context);
    final old=await _askPin(s.pinEnter);if(old==null)return;
    if(!await _verifyPin(old)){snack(s.pinWrong);return;}
    final p1=await _askPin(s.pinCreate);if(p1==null)return;
    final p2=await _askPin(s.pinRepeat);if(p2==null)return;
    if(p1!=p2){snack(s.pinMismatch);return;}
    await _setPin(p1);
    if(mounted)setState(()=>pinOn=true);
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return _SubScaffold(
      title:s.security,
      subtitle:s.securityRealSub,
      child:ListView(
        padding:const EdgeInsets.fromLTRB(18,4,18,110),
        children:[
          _VibeGroup(title:s.secSectionPin,children:[
            SwitchListTile(
              contentPadding:const EdgeInsets.fromLTRB(16,8,16,4),
              secondary:_IconBadge(icon:pinOn?Icons.lock_rounded:Icons.lock_open_rounded,color:pinOn?green:context.cMut),
              value:pinOn,
              title:Text(s.pinLock,style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text(s.secPinSub,style:TextStyle(color:context.cMut,fontSize:12)),
              onChanged:_togglePin,
            ),
            if(pinOn)...[
              SwitchListTile(
                contentPadding:const EdgeInsets.symmetric(horizontal:16),
                secondary:_IconBadge(icon:Icons.smartphone_rounded,color:blue),
                value:pinBg,
                title:Text(s.pinBg,style:const TextStyle(fontWeight:FontWeight.w700)),
                subtitle:Text(s.pinBgSub,style:TextStyle(color:context.cMut,fontSize:12)),
                onChanged:(v)async{setState(()=>pinBg=v);gPinBg=v;final p=await SharedPreferences.getInstance();await p.setBool('pin_bg',v);},
              ),
              ListTile(
                contentPadding:const EdgeInsets.fromLTRB(16,0,16,10),
                leading:_IconBadge(icon:Icons.password_rounded,color:purple),
                title:Text(s.pinChange,style:const TextStyle(fontWeight:FontWeight.w700)),
                onTap:_changePin,
              ),
            ],
          ]),
          _VibeGroup(title:s.secSectionScreen,children:[
            SwitchListTile(
              contentPadding:const EdgeInsets.fromLTRB(16,8,16,10),
              secondary:_IconBadge(icon:Icons.screenshot_monitor_outlined,color:pink),
              value:secure,
              title:Text(s.screenshots,style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text(s.secShotsSub2,style:TextStyle(color:context.cMut,fontSize:12)),
              // Мгновенный отклик: сначала UI, затем сохранение и нативный FLAG_SECURE
              onChanged:(v){
                setState(()=>secure=v);
                SharedPreferences.getInstance().then((p)=>p.setBool('secure_mode',v));
                applySecureFlag(v);
              },
            ),
          ]),
          const SizedBox(height:8),
          Padding(
            padding:const EdgeInsets.symmetric(horizontal:6),
            child:Text(s.securityNote,style:TextStyle(color:context.cMut,fontSize:12,height:1.45)),
          ),
        ],
      ),
    );
  }
}

// ===== Общие детали Telegram-стиля: подстраница, бейдж иконки, группа, чип выбора =====
class _SubScaffold extends StatelessWidget{
  final String title;final String? subtitle;final Widget child;
  const _SubScaffold({required this.title,this.subtitle,required this.child});
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      titleSpacing:0,
      title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
        if(subtitle!=null)Text(subtitle!,style:TextStyle(color:context.cMut,fontSize:11,fontWeight:FontWeight.w600)),
      ]),
    ),
    body:child,
  );
}
class _IconBadge extends StatelessWidget{
  final IconData icon;final Color color;
  const _IconBadge({required this.icon,required this.color});
  @override Widget build(BuildContext context)=>Container(width:36,height:36,decoration:BoxDecoration(color:color.withOpacity(.15),borderRadius:BorderRadius.circular(12)),child:Icon(icon,size:19,color:color));
}
class _VibeGroup extends StatelessWidget{
  final String? title;final List<Widget> children;
  const _VibeGroup({this.title,required this.children});
  @override Widget build(BuildContext context){
    final rows=<Widget>[];
    for(int i=0;i<children.length;i++){
      if(i>0)rows.add(Divider(height:1,indent:66,color:context.cLine.withOpacity(.45)));
      rows.add(children[i]);
    }
    return Padding(
      padding:const EdgeInsets.only(top:16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        if(title!=null)Padding(padding:const EdgeInsets.only(left:16,bottom:7),child:Text(title!.toUpperCase(),style:TextStyle(color:context.cMut,fontSize:10.5,fontWeight:FontWeight.w900,letterSpacing:1.2))),
        Material(color:context.cSurf,borderRadius:BorderRadius.circular(22),clipBehavior:Clip.antiAlias,child:Column(children:rows)),
      ]),
    );
  }
}
class _ChoiceChip extends StatelessWidget{
  final String label;final bool active;final VoidCallback onTap;
  const _ChoiceChip({required this.label,required this.active,required this.onTap});
  @override Widget build(BuildContext context)=>Material(
    color:Colors.transparent,
    child:InkWell(
      onTap:onTap,
      borderRadius:BorderRadius.circular(14),
      child:AnimatedContainer(
        duration:const Duration(milliseconds:180),
        curve:Curves.easeOutCubic,
        height:44,
        alignment:Alignment.center,
        decoration:BoxDecoration(
          gradient:active?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad):null,
          color:active?null:context.cSurf2.withOpacity(.55),
          borderRadius:BorderRadius.circular(14),
          border:Border.all(color:active?Colors.transparent:context.cLine),
        ),
        child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          if(active)const Icon(Icons.check_rounded,size:16,color:Colors.white),
          if(active)const SizedBox(width:6),
          Text(label,style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:active?Colors.white:context.cMut)),
        ]),
      ),
    ),
  );
}

// ===== Карточка выбора темы (Оформление) =====
class _ThemeCard extends StatelessWidget{
  final bool dark,selected;final String label;final VoidCallback? onTap;
  const _ThemeCard({required this.dark,required this.selected,required this.label,required this.onTap});
  @override Widget build(BuildContext context){
    return Material(
      type:MaterialType.transparency,
      child:InkWell(
        onTap:onTap,
        borderRadius:BorderRadius.circular(20),
        child:AnimatedContainer(
          duration:const Duration(milliseconds:200),
          curve:Curves.easeOutCubic,
          padding:const EdgeInsets.all(3),
          decoration:BoxDecoration(
            gradient:selected?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad):null,
            color:selected?null:Colors.transparent,
            borderRadius:BorderRadius.circular(20),
            border:Border.all(color:selected?Colors.transparent:context.cLine),
            boxShadow:selected?[BoxShadow(color:pink.withOpacity(.28),blurRadius:18,offset:const Offset(0,6))]:null,
          ),
          child:Container(
            padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(
              color:dark?const Color(0xFF0A0A10):const Color(0xFFF3F1FA),
              borderRadius:BorderRadius.circular(17),
            ),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Row(children:[
                Container(width:15,height:15,decoration:const BoxDecoration(color:purple,shape:BoxShape.circle)),
                const SizedBox(width:6),
                Container(width:15,height:15,decoration:const BoxDecoration(color:pink,shape:BoxShape.circle)),
                const Spacer(),
                Container(width:34,height:12,decoration:BoxDecoration(color:dark?const Color(0xFF1C1C26):Colors.white,borderRadius:BorderRadius.circular(4))),
              ]),
              const SizedBox(height:9),
              Container(height:8,decoration:BoxDecoration(gradient:const LinearGradient(colors:brandGrad),borderRadius:BorderRadius.circular(4))),
              const SizedBox(height:12),
              Row(children:[
                if(selected)Icon(Icons.check_circle_rounded,size:15,color:pink)else Icon(Icons.circle_outlined,size:14,color:dark?context.cMut:Colors.black26),
                const SizedBox(width:6),
                Text(label,style:TextStyle(fontSize:12.5,fontWeight:FontWeight.w800,color:dark?Colors.white:const Color(0xFF171522))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ===== Аватар с градиентным кольцом и кнопкой камеры (редактор профиля) =====
class _AvatarPicker extends StatelessWidget{
  final String name;final String? url;final VoidCallback onTap;
  const _AvatarPicker({required this.name,required this.url,required this.onTap});
  @override Widget build(BuildContext context){
    final hasPhoto=Avatar.bytes(url)!=null;
    return InkWell(
      onTap:onTap,
      borderRadius:BorderRadius.circular(44),
      child:Stack(
        clipBehavior:Clip.none,
        children:[
          Container(
            padding:const EdgeInsets.all(3),
            decoration:BoxDecoration(
              gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),
              borderRadius:BorderRadius.circular(42),
              boxShadow:[BoxShadow(color:pink.withOpacity(.32),blurRadius:26,spreadRadius:-4,offset:const Offset(0,8))],
            ),
            child:Avatar(name:name,size:112,url:url),
          ),
          Positioned(
            right:-2,bottom:-2,
            child:Container(
              width:36,height:36,
              decoration:BoxDecoration(
                gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:brandGrad),
                shape:BoxShape.circle,
                border:Border.all(color:const Color(0xFF15151D),width:3),
              ),
              child:Icon(hasPhoto?Icons.auto_fix_high_rounded:Icons.add_a_photo_rounded,size:17,color:Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Экран блокировки (PIN) =====
class LockScreen extends StatelessWidget{
  final VoidCallback onUnlock;final Future<void> Function() onSignOut;
  const LockScreen({super.key,required this.onUnlock,required this.onSignOut});
  @override Widget build(BuildContext context){
    final s=S(context);
    return _PinScreen(
      title:s.lockedTitle,
      sub:s.pinUnlock,
      signOut:true,
      popOnSuccess:false,
      onSignOut:onSignOut,
      onEnter:(pin)async{
        final p=await SharedPreferences.getInstance();
        if(pinHash(pin)==(p.getString('pin_hash')??'')){onUnlock();return true;}
        return false;
      },
    );
  }
}

class _PinScreen extends StatefulWidget{
  final String title;final String? sub;final Future<bool> Function(String pin) onEnter;
  final bool signOut;final bool popOnSuccess;final Future<void> Function()? onSignOut;
  const _PinScreen({required this.title,this.sub,required this.onEnter,this.signOut=false,this.popOnSuccess=true,this.onSignOut});
  @override State<_PinScreen> createState()=>_PinScreenState();
}
class _PinScreenState extends State<_PinScreen> with SingleTickerProviderStateMixin{
  String code='';bool busy=false,error=false;
  late final AnimationController shake=AnimationController(vsync:this,duration:const Duration(milliseconds:420));
  @override void dispose(){shake.dispose();super.dispose();}
  void _tap(String d){
    if(busy||code.length>=4)return;
    setState((){code+=d;error=false;});
    if(code.length==4)_submit();
  }
  void _back(){if(busy||code.isEmpty)return;setState(()=>code=code.substring(0,code.length-1));}
  Future<void> _submit()async{
    setState(()=>busy=true);
    bool ok;
    try{ok=await widget.onEnter(code);}catch(_){ok=false;}
    if(!mounted)return;
    if(ok){
      if(widget.popOnSuccess)Navigator.pop(context,code);
      else setState(()=>busy=false); // LockScreen: состояние приложения меняется само
    }else{
      shake.forward(from:0);
      setState((){busy=false;code='';error=true;});
    }
  }
  @override Widget build(BuildContext context){
    final s=S(context);
    return Scaffold(
      backgroundColor:context.cBg,
      body:Stack(children:[
        const Positioned.fill(child:VibeAnimatedBackground()),
        SafeArea(child:Padding(
          padding:const EdgeInsets.symmetric(horizontal:34),
          child:Column(children:[
            const Spacer(),
            const _BrandMark(),
            const SizedBox(height:22),
            AnimatedBuilder(
              animation:shake,
              builder:(_,child)=>Transform.translate(offset:Offset(math.sin(shake.value*math.pi*5)*(1-shake.value)*12,0),child:child),
              child:Column(children:[
                Text(widget.title,textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:context.cTxt)),
                if(widget.sub!=null)...[
                  const SizedBox(height:7),
                  Text(widget.sub!,style:TextStyle(color:context.cMut,fontSize:13)),
                ],
                const SizedBox(height:22),
                Row(
                  mainAxisAlignment:MainAxisAlignment.center,
                  children:[for(int i=0;i<4;i++)Container(
                    margin:const EdgeInsets.symmetric(horizontal:7),
                    width:16,height:16,
                    decoration:BoxDecoration(
                      shape:BoxShape.circle,
                      color:i<code.length?(error?pink:purple):Colors.transparent,
                      border:error&&i>=code.length?Border.all(color:pink,width:1.6):Border.all(color:i<code.length?Colors.transparent:context.cLine,width:1.6),
                    ),
                  )],
                ),
                if(error)...[
                  const SizedBox(height:12),
                  Text(s.pinWrong,style:const TextStyle(color:pink,fontSize:12.5,fontWeight:FontWeight.w800)),
                ],
              ]),
            ),
            const SizedBox(height:26),
            _PinPad(onDigit:_tap,onBack:_back,busy:busy),
            const Spacer(),
            if(widget.signOut)Padding(
              padding:const EdgeInsets.only(bottom:16),
              child:TextButton.icon(
                onPressed:busy?null:()async{
                  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(s.pinSignOut),content:Text(s.pinSignOutQ),actions:[
                    TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(s.cancel)),
                    FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(s.pinSignOut)),
                  ]));
                  if(ok==true)await widget.onSignOut!();
                },
                icon:const Icon(Icons.logout_rounded,size:17,color:pink),
                label:Text(s.pinSignOut,style:const TextStyle(color:pink,fontSize:13)),
              ),
            ),
          ]),
        )),
      ]),
    );
  }
}

class _PinPad extends StatelessWidget{
  final ValueChanged<String> onDigit;final VoidCallback onBack;final bool busy;
  const _PinPad({required this.onDigit,required this.onBack,required this.busy});
  Widget _key(BuildContext c2,String k)=>k.isEmpty
    ?const SizedBox(width:76,height:64)
    :Padding(
      padding:const EdgeInsets.all(5),
      child:Material(
        color:Colors.transparent,
        child:InkWell(
          onTap:busy?null:(k=='back'?onBack:()=>onDigit(k)),
          borderRadius:BorderRadius.circular(19),
          splashColor:pink.withOpacity(.10),
          child:Container(
            width:66,height:56,
            alignment:Alignment.center,
            decoration:BoxDecoration(
              color:c2.cSurf.withOpacity(.72),
              borderRadius:BorderRadius.circular(18),
              border:Border.all(color:c2.cLine),
            ),
            child:k=='back'
              ?Icon(Icons.backspace_outlined,size:21,color:c2.cMut)
              :Text(k,style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:c2.cTxt)),
          ),
        ),
      ),
    );
  @override Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    for(final row in const[['1','2','3'],['4','5','6'],['7','8','9'],['','0','back']])
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[for(final k in row)_key(context,k)]),
  ]);
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
    backgroundColor:context.cBg,
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
              Text('private. personal. yours.',style:TextStyle(color:context.cMut,fontSize:12,fontWeight:FontWeight.w600)),
              const SizedBox(height:26),
              SizedBox(width:92,height:3,child:ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:reveal.value,minHeight:3,backgroundColor:context.cLine))),
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
    SizedBox(height:18),Text(title,textAlign:TextAlign.center,style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),SizedBox(height:7),Text(sub,textAlign:TextAlign.center,style:TextStyle(color:context.cMut,fontSize:13,height:1.45)),
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
            color:gradient?null:(dark?context.cSurf2:Color(0xFFECEAF2)),
            borderRadius:BorderRadius.circular(size*.36),
            border:gradient?Border.all(color:Colors.white.withOpacity(.12)):Border.all(color:dark?context.cLine:Colors.black12),
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
