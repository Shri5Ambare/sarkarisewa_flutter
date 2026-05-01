// lib/l10n/strings.dart — bilingual translation map (mirrors web i18n.js)
const Map<String, Map<String, String>> appStrings = {
  'brand.name':      {'en': 'SarkariSewa',       'ne': 'सरकारी सेवा'},
  'brand.tagline':   {'en': "Nepal's #1 AI-Powered Exam Prep", 'ne': 'नेपालको नम्बर १ AI परीक्षा तयारी'},

  // Auth
  'login.title':     {'en': 'Welcome Back',       'ne': 'फेरि स्वागत छ'},
  'login.subtitle':  {'en': 'Continue your exam preparation', 'ne': 'परीक्षा तयारी जारी राख्नुहोस्'},
  'login.email':     {'en': 'Email Address',      'ne': 'इमेल ठेगाना'},
  'login.password':  {'en': 'Password',           'ne': 'पासवर्ड'},
  'login.btn':       {'en': 'Sign In',            'ne': 'साइन इन'},
  'login.forgotPwd': {'en': 'Forgot password?',   'ne': 'पासवर्ड बिर्सनुभयो?'},
  'login.noAccount': {'en': "New to SarkariSewa?",'ne': 'SarkariSewa मा नयाँ छ?'},
  'login.createAcc': {'en': 'Create Account',     'ne': 'खाता बनाउनुहोस्'},
  'login.demo':      {'en': 'Demo Accounts',      'ne': 'डेमो खाताहरू'},

  'signup.title':    {'en': 'Create Account',     'ne': 'खाता बनाउनुहोस्'},
  'signup.subtitle': {'en': 'Join 15,000+ students', 'ne': '१५,०००+ विद्यार्थीसँग सामेल हुनुहोस्'},
  'signup.name':     {'en': 'Full Name',          'ne': 'पूरा नाम'},
  'signup.qual':     {'en': 'Qualification',      'ne': 'योग्यता'},
  'signup.btn':      {'en': 'Create Account',     'ne': 'खाता बनाउनुहोस्'},
  'signup.hasAcct':  {'en': 'Already have an account?', 'ne': 'पहिले नै खाता छ?'},

  'forgot.title':    {'en': 'Reset Password',     'ne': 'पासवर्ड रिसेट'},
  'forgot.sub':      {'en': "We'll send a reset link to your email", 'ne': 'तपाईंको इमेलमा रिसेट लिंक पठाउनेछौं'},
  'forgot.btn':      {'en': 'Send Reset Email',   'ne': 'रिसेट इमेल पठाउनुहोस्'},
  'forgot.success':  {'en': 'Reset link sent! Check your inbox.', 'ne': 'रिसेट लिंक पठाइयो!'},

  // Dashboard
  'dashboard.title': {'en': 'My Dashboard',       'ne': 'मेरो ड्यासबोर्ड'},
  'dashboard.courses':{'en': 'Available Courses',  'ne': 'उपलब्ध कोर्सहरू'},
  'dashboard.search':{'en': 'Search courses…',    'ne': 'कोर्स खोज्नुहोस्…'},
  'dashboard.enrolled':{'en': 'Enrolled',        'ne': 'भर्ना भएको'},
  'dashboard.noResults':{'en': 'No courses found', 'ne': 'कुनै कोर्स फेला परेन'},

  // Course
  'course.enroll':   {'en': 'Buy Now',            'ne': 'अहिले किन्नुहोस्'},
  'course.enrolled': {'en': 'Enrolled',         'ne': 'भर्ना भएको'},
  'course.syllabus': {'en': 'Syllabus',           'ne': 'पाठ्यक्रम'},
  'course.videos':   {'en': 'Video Lectures',     'ne': 'भिडियो व्याख्यान'},
  'course.classes':  {'en': 'Live Classes',       'ne': 'लाइभ कक्षाहरू'},
  'course.locked':   {'en': 'Locked — Purchase to unlock', 'ne': 'लक — खरिद गर्नुहोस्'},
  'course.join':     {'en': 'Join Class',         'ne': 'कक्षामा सामेल हुनुहोस्'},

  // AI Viva
  'viva.title':      {'en': 'AI Conversational Viva', 'ne': 'AI कुराकानी भाइभा'},
  'viva.start':      {'en': 'Start Session',      'ne': 'सत्र सुरु गर्नुहोस्'},
  'viva.stop':       {'en': 'End Session',        'ne': 'सत्र समाप्त गर्नुहोस्'},
  'viva.nextQ':      {'en': 'Next Question',      'ne': 'अर्को प्रश्न'},
  'viva.remaining':  {'en': 'remaining',          'ne': 'बाँकी'},
  'viva.selectCourse':{'en': 'Select Course',     'ne': 'कोर्स छान्नुहोस्'},
  'viva.recording':  {'en': 'Recording…',         'ne': 'रेकर्डिङ…'},
  'viva.locked':     {'en': 'Session Locked',     'ne': 'सत्र लक गरियो'},

  // Writing
  'writing.title':   {'en': 'Writing Submission', 'ne': 'लेखन पेश'},
  'writing.submit':  {'en': 'Submit Paper',       'ne': 'पेपर पेश गर्नुहोस्'},
  'writing.history': {'en': 'My Submissions',     'ne': 'मेरा पेश गरिएका'},
  'writing.noAccess':{'en': 'Writing access not granted', 'ne': 'लेखन पहुँच छैन'},
  'writing.pending': {'en': 'Pending',            'ne': 'पेन्डिङ'},
  'writing.reviewed':{'en': 'Reviewed',           'ne': 'समीक्षा गरियो'},

  // Social
  'social.title':    {'en': 'Social & Battles',   'ne': 'सामाजिक र प्रतिस्पर्धा'},
  'social.leaderboard':{'en': 'Leaderboard',      'ne': 'लिडरबोर्ड'},
  'social.challenge':{'en': 'Challenge',          'ne': 'चुनौती दिनुहोस्'},
  'social.battlePts':{'en': 'pts',                'ne': 'अंक'},

  // Profile
  'profile.title':   {'en': 'My Profile',         'ne': 'मेरो प्रोफाइल'},
  'profile.save':    {'en': 'Save Changes',       'ne': 'परिवर्तन सुरक्षित'},
  'profile.changePwd':{'en': 'Change Password',   'ne': 'पासवर्ड परिवर्तन'},
  'profile.enrolled':{'en': 'Enrolled Courses',   'ne': 'भर्ना भएका कोर्सहरू'},
  'profile.joined':  {'en': 'Member since',       'ne': 'सदस्य देखि'},
  'profile.tier':    {'en': 'Current Plan',       'ne': 'हालको योजना'},

  // Order
  'order.title':     {'en': 'Order Placed!',      'ne': 'अर्डर गरियो!'},
  'order.message':   {'en': 'We will contact you via email to activate your course access.', 'ne': 'तपाईंको कोर्स एक्सेस सक्रिय गर्न हामी इमेलमा सम्पर्क गर्नेछौं।'},
  'order.back':      {'en': 'Back to Dashboard',  'ne': 'ड्यासबोर्डमा फर्कनुहोस्'},

  // Admin / Teacher
  'admin.title':     {'en': 'Admin Panel',        'ne': 'प्रशासन'},
  'admin.users':     {'en': 'Users',              'ne': 'प्रयोगकर्ताहरू'},
  'admin.orders':    {'en': 'Orders',             'ne': 'अर्डरहरू'},
  'admin.activate':  {'en': 'Activate',           'ne': 'सक्रिय गर्नुहोस्'},
  'teacher.title':   {'en': 'Submissions',        'ne': 'पेश गरिएका'},
  'teacher.remark':  {'en': 'Add Remark',         'ne': 'टिप्पणी थप्नुहोस्'},

  // Common
  'common.loading':  {'en': 'Loading…',           'ne': 'लोड हुँदैछ…'},
  'common.save':     {'en': 'Save',               'ne': 'सुरक्षित'},
  'common.cancel':   {'en': 'Cancel',             'ne': 'रद्द'},
  'common.logout':   {'en': 'Logout',             'ne': 'लग आउट'},
  'common.upgrade':  {'en': 'Upgrade Now',        'ne': 'अपग्रेड गर्नुहोस्'},
  'common.free':     {'en': 'Free',               'ne': 'नि:शुल्क'},
  'common.error':    {'en': 'Something went wrong. Please try again.', 'ne': 'केही गलत भयो।'},
  'common.plan.free':{'en': '🆓 Free Plan',       'ne': '🆓 नि:शुल्क'},
  'common.plan.silver':{'en': '🥈 Silver Plan',   'ne': '🥈 सिल्भर'},
  'common.plan.gold':  {'en': '🥇 Gold Plan',     'ne': '🥇 गोल्ड'},
  'notfound.title':  {'en': 'Page Not Found',     'ne': 'पृष्ठ फेला परेन'},
  'notfound.btn':    {'en': 'Go to Dashboard',    'ne': 'ड्यासबोर्डमा जानुहोस्'},
  'nav.home':        {'en': 'Home',               'ne': 'गृह'},
  'nav.pyq':         {'en': 'PYQ',                'ne': 'पुराना प्रश्न'},
  'nav.mock':        {'en': 'Mock',               'ne': 'मक टेस्ट'},
  'nav.live':        {'en': 'Live',               'ne': 'लाइभ'},
  'nav.writing':     {'en': 'Writing',            'ne': 'लेखन'},
  'nav.social':      {'en': 'Battles',            'ne': 'प्रतिस्पर्धा'},
  'nav.profile':     {'en': 'Profile',            'ne': 'प्रोफाइल'},
};

/// Get a translated string. Falls back to English, then the key itself.
String t(String key, String lang) {
  final entry = appStrings[key];
  if (entry == null) return key;
  return entry[lang] ?? entry['en'] ?? key;
}
