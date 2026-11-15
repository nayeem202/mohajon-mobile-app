/// Offline help content. Keep both languages together so additions cannot
/// accidentally ship an English-only or Bangla-only question.
class HelpFaqEntry {
  const HelpFaqEntry({
    required this.id,
    required this.questionEn,
    required this.questionBn,
    required this.answerEn,
    required this.answerBn,
  });

  final String id;
  final String questionEn;
  final String questionBn;
  final String answerEn;
  final String answerBn;

  String question(String languageCode) =>
      languageCode == 'bn' ? questionBn : questionEn;
  String answer(String languageCode) =>
      languageCode == 'bn' ? answerBn : answerEn;

  bool matches(String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    final text = '$questionEn $questionBn $answerEn $answerBn'.toLowerCase();
    return terms.every(text.contains);
  }
}

class HelpFaqTopic {
  const HelpFaqTopic({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.entries,
  });

  final String id;
  final String titleEn;
  final String titleBn;
  final List<HelpFaqEntry> entries;

  String title(String languageCode) => languageCode == 'bn' ? titleBn : titleEn;
}

List<HelpFaqEntry> filterHelpFaqs(HelpFaqTopic topic, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return topic.entries;
  final topicText = '${topic.titleEn} ${topic.titleBn}'.toLowerCase();
  return topic.entries.where((entry) {
    final terms = normalized.split(RegExp(r'\s+'));
    return terms.every(
      (term) => topicText.contains(term) || entry.matches(term),
    );
  }).toList();
}

const helpFaqTopics = <HelpFaqTopic>[
  HelpFaqTopic(
    id: 'getting-started',
    titleEn: 'Getting started & account',
    titleBn: 'শুরু ও অ্যাকাউন্ট',
    entries: [
      HelpFaqEntry(
        id: 'about',
        questionEn: 'What can I manage with Mohajon?',
        questionBn: 'মহাজন দিয়ে কী কী পরিচালনা করতে পারি?',
        answerEn:
            'Manage shop products, stock, sales, customers, dues, supplier purchases, expenses and reports. Staff, branches, investments and Mohajon AI are available according to your access, plan and service availability.',
        answerBn:
            'দোকানের পণ্য, স্টক, বিক্রয়, গ্রাহক, বাকি, সরবরাহকারীর কেনাকাটা, খরচ ও রিপোর্ট পরিচালনা করতে পারেন। স্টাফ, শাখা, বিনিয়োগ ও মহাজন AI ব্যবহারের সুযোগ আপনার অনুমতি, প্ল্যান ও সেবার প্রাপ্যতার ওপর নির্ভর করে।',
      ),
      HelpFaqEntry(
        id: 'register',
        questionEn: 'How do I create an account and set up my shop?',
        questionBn: 'কীভাবে অ্যাকাউন্ট খুলে দোকান সেটআপ করব?',
        answerEn:
            'Choose Sign up on the login screen, enter the requested details and verify your email. Then complete shop setup with the correct business category and shop information. Account creation and verification require internet.',
        answerBn:
            'লগইন স্ক্রিন থেকে নিবন্ধন বেছে প্রয়োজনীয় তথ্য দিন ও ইমেইল যাচাই করুন। এরপর সঠিক ব্যবসার ধরন ও দোকানের তথ্য দিয়ে সেটআপ শেষ করুন। অ্যাকাউন্ট খোলা ও যাচাইয়ের জন্য ইন্টারনেট দরকার।',
      ),
      HelpFaqEntry(
        id: 'verification-email',
        questionEn: 'Why have I not received the verification email or code?',
        questionBn: 'যাচাইকরণের ইমেইল বা কোড পাচ্ছি না কেন?',
        answerEn:
            'Check the email spelling, Spam/Junk folder and internet connection. Use the latest code or verification link. If the code has expired, request another after the resend cooldown. If it still does not arrive, contact support; do not keep creating new accounts.',
        answerBn:
            'ইমেইল ঠিকানা, স্প্যাম/জাঙ্ক ফোল্ডার ও ইন্টারনেট পরীক্ষা করুন। সর্বশেষ কোড বা যাচাইকরণ লিংক ব্যবহার করুন। কোডের মেয়াদ শেষ হলে পুনরায় পাঠানোর অপেক্ষার সময় শেষে নতুন কোড চান। তবুও না এলে বারবার নতুন অ্যাকাউন্ট না খুলে সাপোর্টে জানান।',
      ),
      HelpFaqEntry(
        id: 'forgot-password',
        questionEn: 'What should I do if I forget my password?',
        questionBn: 'পাসওয়ার্ড ভুলে গেলে কী করব?',
        answerEn:
            'Tap Forgot password on the login screen. Enter your registered email and follow the reset-code steps to set a new password. Do not share the code or new password with anyone, including someone claiming to be support.',
        answerBn:
            'লগইন স্ক্রিনে পাসওয়ার্ড ভুলে গেছেন অপশনে চাপুন। নিবন্ধিত ইমেইল দিয়ে রিসেট কোডের ধাপ অনুসরণ করে নতুন পাসওয়ার্ড দিন। সাপোর্ট পরিচয় দিলেও কাউকে কোড বা নতুন পাসওয়ার্ড দেবেন না।',
      ),
      HelpFaqEntry(
        id: 'social-login',
        questionEn: 'Can I sign in with Google or Facebook?',
        questionBn: 'Google বা Facebook দিয়ে লগইন করতে পারব?',
        answerEn:
            'Use the sign-in option shown on your login screen with internet enabled. Availability depends on provider setup and account eligibility. If you cancel the provider screen, return and try again when ready. If the provider is unavailable, use a sign-in method already linked to your account.',
        answerBn:
            'ইন্টারনেট চালু রেখে লগইন স্ক্রিনে দেখানো অপশন ব্যবহার করুন। এটি সেবার কনফিগারেশন ও অ্যাকাউন্টের যোগ্যতার ওপর নির্ভর করে। মাঝপথে বাতিল করলে পরে আবার চেষ্টা করতে পারেন। সেবা না চললে আপনার অ্যাকাউন্টে আগে যুক্ত করা লগইন পদ্ধতি ব্যবহার করুন।',
      ),
      HelpFaqEntry(
        id: 'shop-details',
        questionEn: 'Where do I change my shop name, phone number or logo?',
        questionBn: 'দোকানের নাম, ফোন নম্বর বা লোগো কোথায় পরিবর্তন করব?',
        answerEn:
            'Open My profile, then Store / Business information. Edit the available fields, save, and sync when online. Locally saved shop information remains available offline; an image may need to be downloaded first to appear offline.',
        answerBn:
            'আমার প্রোফাইল থেকে দোকান/ব্যবসার তথ্যে যান। প্রয়োজনীয় তথ্য পরিবর্তন করে সংরক্ষণ করুন এবং অনলাইনে সিঙ্ক করুন। ফোনে সংরক্ষিত দোকানের তথ্য অফলাইনেও থাকে; ছবি অফলাইনে দেখাতে আগে ডাউনলোড হওয়া লাগতে পারে।',
      ),
      HelpFaqEntry(
        id: 'language',
        questionEn: 'How do I switch between Bangla and English?',
        questionBn: 'বাংলা ও ইংরেজি ভাষা কীভাবে বদলাব?',
        answerEn:
            'Open Settings and choose the app language under App preferences. FAQ questions and answers follow that language. Product and customer names remain the information you entered; changing the app language does not translate your records.',
        answerBn:
            'সেটিংসের অ্যাপ পছন্দসমূহ থেকে ভাষা নির্বাচন করুন। FAQ-এর প্রশ্ন–উত্তরও সেই ভাষায় দেখাবে। পণ্য ও গ্রাহকের নাম আপনার দেওয়া তথ্য হিসেবেই থাকবে; ভাষা বদলালে ব্যবসার রেকর্ড অনুবাদ হয় না।',
      ),
      HelpFaqEntry(
        id: 'missing-feature',
        questionEn:
            'Why is a feature missing or showing an access restriction?',
        questionBn:
            'কোনো ফিচার দেখা যাচ্ছে না বা ব্যবহার করতে বাধা দিচ্ছে কেন?',
        answerEn:
            'Some features need owner permission, an eligible subscription, internet or an updated app. Check your role, current branch and Subscription screen. Ask the shop owner or contact support if the restriction seems incorrect.',
        answerBn:
            'কিছু ফিচারের জন্য মালিকের অনুমতি, উপযুক্ত সাবস্ক্রিপশন, ইন্টারনেট বা হালনাগাদ অ্যাপ দরকার। আপনার ভূমিকা, নির্বাচিত শাখা ও সাবস্ক্রিপশন দেখুন। বাধা ভুল মনে হলে দোকানের মালিক বা সাপোর্টে জানান।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'stock',
    titleEn: 'Products & stock',
    titleBn: 'পণ্য ও স্টক',
    entries: [
      HelpFaqEntry(
        id: 'add-product',
        questionEn: 'How do I add a new product?',
        questionBn: 'নতুন পণ্য কীভাবে যোগ করব?',
        answerEn:
            'Open Stock and tap Add / +. Enter the product name, category, unit, purchase and selling prices, stock quantity and low-stock alert. Add a barcode, photo or expiry information where needed, then save.',
        answerBn:
            'স্টক থেকে যোগ করুন / + চাপুন। পণ্যের নাম, ক্যাটাগরি, একক, ক্রয়মূল্য, বিক্রয়মূল্য, স্টকের পরিমাণ ও কম স্টকের সতর্কতা দিন। প্রয়োজনে বারকোড, ছবি বা মেয়াদের তথ্য দিয়ে সংরক্ষণ করুন।',
      ),
      HelpFaqEntry(
        id: 'product-category',
        questionEn:
            'Why do product and supplier categories depend on my shop type?',
        questionBn:
            'দোকানের ধরন অনুযায়ী পণ্য ও সরবরাহকারীর ক্যাটাগরি কেন বদলায়?',
        answerEn:
            'Category choices are based on the business category selected for your shop. Check your shop information if the choices do not match your business. Categories and units have Bangla and English display labels where provided.',
        answerBn:
            'দোকানের জন্য নির্বাচিত ব্যবসার ধরন অনুযায়ী ক্যাটাগরি দেখানো হয়। তালিকা ব্যবসার সঙ্গে না মিললে দোকানের তথ্যের ব্যবসার ধরন পরীক্ষা করুন। দেওয়া ক্যাটাগরি ও এককের বাংলা ও ইংরেজি নাম ভাষা অনুযায়ী দেখায়।',
      ),
      HelpFaqEntry(
        id: 'units',
        questionEn: 'How do I choose the unit and sale quantity?',
        questionBn: 'পণ্যের একক ও বিক্রির পরিমাণ কীভাবে দেব?',
        answerEn:
            'Choose the unit in the product form and keep its meaning consistent in purchases and sales. The current stock and sales flow uses whole-number quantities. Do not enter a fractional quantity such as 0.5 unless that flow explicitly supports it.',
        answerBn:
            'পণ্যের ফর্মে একক নির্বাচন করুন এবং ক্রয়–বিক্রয়ে একই অর্থে ব্যবহার করুন। বর্তমান স্টক ও বিক্রয় ব্যবস্থায় পূর্ণ সংখ্যার পরিমাণ ব্যবহৃত হয়। কোনো ফ্লোতে স্পষ্ট সমর্থন না থাকলে ০.৫-এর মতো ভগ্নাংশ দেবেন না।',
      ),
      HelpFaqEntry(
        id: 'stock-adjustment',
        questionEn: 'How do I correct a stock-count difference?',
        questionBn: 'স্টকের গরমিল কীভাবে ঠিক করব?',
        answerEn:
            'First check purchases, sales, returns and the active branch. Use Stock adjustment to record a real physical-count correction with the available note/reason. Do not create a fake sale or purchase just to change stock.',
        answerBn:
            'আগে কেনাকাটা, বিক্রয়, ফেরত ও নির্বাচিত শাখা মিলিয়ে দেখুন। বাস্তবে গুনে পাওয়া পার্থক্য স্টক সমন্বয়ে লিখুন এবং নোট/কারণ দেওয়ার সুযোগ থাকলে উল্লেখ করুন। স্টক বদলানোর জন্য ভুয়া বিক্রয় বা কেনাকাটা করবেন না।',
      ),
      HelpFaqEntry(
        id: 'low-stock',
        questionEn: 'How do low-stock alerts work?',
        questionBn: 'কম স্টকের সতর্কতা কীভাবে কাজ করে?',
        answerEn:
            'Set an alert quantity for each product. Check Low-stock products to see items that need attention and use the purchase planner before restocking. A product with no stock is not automatically reordered or purchased for you.',
        answerBn:
            'প্রতিটি পণ্যের জন্য সতর্কতার পরিমাণ দিন। কম স্টকের পণ্য তালিকা ও ক্রয় পরিকল্পনা দেখে পুনরায় পণ্য আনুন। স্টক শেষ হলেই অ্যাপ আপনার হয়ে স্বয়ংক্রিয় অর্ডার বা কেনাকাটা করে না।',
      ),
      HelpFaqEntry(
        id: 'stock-search',
        questionEn: 'How do I search stock or filter by category?',
        questionBn: 'স্টকে পণ্য খুঁজব বা ক্যাটাগরি দিয়ে ছাঁকব কীভাবে?',
        answerEn:
            'Tap the search icon in Stock and enter a product name or barcode. Use the category selector to narrow the list, and clear the query/filter to see all available products in the selected branch.',
        answerBn:
            'স্টকের সার্চ আইকনে চাপ দিয়ে পণ্যের নাম বা বারকোড লিখুন। ক্যাটাগরি নির্বাচন করে তালিকা ছোট করুন। নির্বাচিত শাখার সব পণ্য দেখতে সার্চ ও ফিল্টার মুছে দিন।',
      ),
      HelpFaqEntry(
        id: 'barcode',
        questionEn: 'How do barcode scanning and labels work?',
        questionBn: 'বারকোড স্ক্যান ও লেবেল কীভাবে ব্যবহার করব?',
        answerEn:
            'Save the correct barcode on the product, then use the scanner to find that item. Allow camera access when asked. Use the barcode-label action where available to prepare labels; scanning alone does not create a new product or complete a sale.',
        answerBn:
            'পণ্যে সঠিক বারকোড সংরক্ষণ করে স্ক্যানার দিয়ে সেটি খুঁজুন। চাইলে ক্যামেরার অনুমতি দিন। লেবেল তৈরির অপশন থাকলে সেখান থেকে লেবেল প্রস্তুত করুন। শুধু স্ক্যান করলেই নতুন পণ্য তৈরি বা বিক্রয় সম্পন্ন হয় না।',
      ),
      HelpFaqEntry(
        id: 'expiry-batch',
        questionEn: 'How do I track batches and expiry dates?',
        questionBn: 'ব্যাচ ও মেয়াদ কীভাবে হিসাব রাখব?',
        answerEn:
            'Enter batch number and expiry details when adding or receiving goods. Check expiry information before selling. Expired products can be blocked from sale; if batch stock and total stock disagree, review purchases/returns and sync before retrying.',
        answerBn:
            'পণ্য যোগ বা গ্রহণের সময় ব্যাচ নম্বর ও মেয়াদ দিন। বিক্রির আগে মেয়াদ পরীক্ষা করুন। মেয়াদোত্তীর্ণ পণ্য বিক্রিতে বাধা আসতে পারে। ব্যাচ ও মোট স্টক না মিললে কেনাকাটা/ফেরত পর্যালোচনা করে সিঙ্কের পর আবার চেষ্টা করুন।',
      ),
      HelpFaqEntry(
        id: 'edit-price',
        questionEn: 'Does changing a product price change old invoices?',
        questionBn: 'পণ্যের দাম বদলালে পুরোনো চালানও বদলে যাবে?',
        answerEn:
            'Edit the product to use a new price for future sales. A saved sale keeps its recorded prices; changing the current product price is not a way to correct a past sale. Use the appropriate return/correction workflow instead.',
        answerBn:
            'পণ্য সম্পাদনা করে ভবিষ্যৎ বিক্রির জন্য নতুন দাম দিন। সংরক্ষিত বিক্রয়ে তখনকার দাম রেকর্ড থাকে। বর্তমান দাম বদলে পুরোনো বিক্রয় সংশোধন করবেন না; উপযুক্ত ফেরত বা সংশোধনের প্রক্রিয়া ব্যবহার করুন।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'sales',
    titleEn: 'Sales, checkout & returns',
    titleBn: 'বিক্রয়, চেকআউট ও ফেরত',
    entries: [
      HelpFaqEntry(
        id: 'record-sale',
        questionEn: 'How do I record a sale?',
        questionBn: 'বিক্রয় কীভাবে রেকর্ড করব?',
        answerEn:
            'Open Sales / POS, add products to the cart, check quantities and select the customer or walk-in option. Review discount, VAT and payment method, then complete checkout. Confirm that the sale appears in sales history before entering it again.',
        answerBn:
            'বিক্রয় / POS খুলে কার্টে পণ্য যোগ করুন, পরিমাণ দেখুন এবং গ্রাহক বা সাধারণ ক্রেতা নির্বাচন করুন। ছাড়, ভ্যাট ও পেমেন্ট পদ্ধতি যাচাই করে চেকআউট শেষ করুন। আবার একই বিক্রয় দেওয়ার আগে ইতিহাসে সংরক্ষিত হয়েছে কি না দেখুন।',
      ),
      HelpFaqEntry(
        id: 'walk-in',
        questionEn: 'Do I need a customer account for every cash sale?',
        questionBn: 'প্রতিটি নগদ বিক্রয়ে গ্রাহক যোগ করতে হবে?',
        answerEn:
            'Use the walk-in option for an eligible fully paid sale. Select a saved customer when you need an individual statement, loyalty tracking or a due balance. A due sale needs a customer so the outstanding amount can be tracked.',
        answerBn:
            'সম্পূর্ণ পরিশোধিত বিক্রয়ে সাধারণ ক্রেতা অপশন ব্যবহার করতে পারেন। আলাদা হিসাব, লয়্যালটি বা বাকি রাখতে সংরক্ষিত গ্রাহক নির্বাচন করুন। কার কাছে বাকি আছে তা হিসাব রাখতে বাকির বিক্রয়ে গ্রাহক নির্বাচন দরকার।',
      ),
      HelpFaqEntry(
        id: 'partial-due',
        questionEn: 'How do fully paid, partial and due sales differ?',
        questionBn: 'পরিশোধিত, আংশিক ও বাকি বিক্রয়ের পার্থক্য কী?',
        answerEn:
            'A fully paid sale has no outstanding balance. A partial sale records the amount paid and keeps the rest due; a credit sale leaves the unpaid amount due to the selected customer. Use the payment options available in the checkout/payment screen and check the saved status.',
        answerBn:
            'সম্পূর্ণ পরিশোধিত বিক্রয়ে বাকি থাকে না। আংশিক পরিশোধে দেওয়া টাকা জমা হয় ও অবশিষ্ট বাকি থাকে। ধারে বিক্রয়ে অপরিশোধিত টাকা নির্বাচিত গ্রাহকের বাকি হয়। চেকআউট/পেমেন্ট স্ক্রিনে থাকা অপশন অনুযায়ী তথ্য দিয়ে সংরক্ষিত অবস্থা দেখুন।',
      ),
      HelpFaqEntry(
        id: 'vat-discount',
        questionEn: 'How are discount, VAT and the invoice total calculated?',
        questionBn: 'ছাড়, ভ্যাট ও চালানের মোট হিসাব কীভাবে হয়?',
        answerEn:
            'Line amounts are rounded to two decimal places. The discount reduces the goods subtotal, VAT is calculated on the discounted amount, and any recorded charge is added afterward. Review the preview and paid/due amounts before saving.',
        answerBn:
            'পণ্যের প্রতিটি লাইনের টাকা দশমিকের দুই ঘর পর্যন্ত হিসাব হয়। পণ্যের উপমোট থেকে ছাড় বাদ দিয়ে অবশিষ্টের ওপর ভ্যাট হিসাব হয়; রেকর্ড করা অতিরিক্ত চার্জ পরে যোগ হয়। সংরক্ষণের আগে মোট, পরিশোধিত ও বাকি টাকা মিলিয়ে নিন।',
      ),
      HelpFaqEntry(
        id: 'loyalty',
        questionEn: 'How do customer loyalty points and rewards work?',
        questionBn: 'গ্রাহকের লয়্যালটি পয়েন্ট ও পুরস্কার কীভাবে কাজ করে?',
        answerEn:
            'Select the saved customer to see eligible loyalty rewards. Earning/redemption depends on the configured customer rules and recorded payment. Review the reward and final discount at checkout; a reward cannot be used without enough points or eligibility.',
        answerBn:
            'সংরক্ষিত গ্রাহক নির্বাচন করলে প্রযোজ্য লয়্যালটি সুবিধা দেখা যায়। পয়েন্ট পাওয়া ও খরচ করা গ্রাহক-সংক্রান্ত নিয়ম ও রেকর্ড করা পেমেন্টের ওপর নির্ভর করে। চেকআউটে সুবিধা ও মোট ছাড় দেখুন; প্রয়োজনীয় পয়েন্ট বা যোগ্যতা ছাড়া সুবিধা নেওয়া যায় না।',
      ),
      HelpFaqEntry(
        id: 'sales-history',
        questionEn: 'Where can I find an old sale or receipt?',
        questionBn: 'পুরোনো বিক্রয় বা রসিদ কোথায় পাব?',
        answerEn:
            'Open Sales history and use the available search/date filters. Select a sale to inspect its items, customer, payments and receipt actions. Check the active branch if you cannot find the expected sale.',
        answerBn:
            'বিক্রয়ের ইতিহাস খুলে সার্চ ও তারিখের ফিল্টার ব্যবহার করুন। বিক্রয় বেছে পণ্য, গ্রাহক, পেমেন্ট ও রসিদের অপশন দেখুন। প্রত্যাশিত বিক্রয় না পেলে নির্বাচিত শাখা পরীক্ষা করুন।',
      ),
      HelpFaqEntry(
        id: 'sale-return',
        questionEn: 'How do I record a customer return?',
        questionBn: 'গ্রাহকের পণ্য ফেরত কীভাবে রেকর্ড করব?',
        answerEn:
            'Open the original sale and use its return action when available. Select the returned items and quantities, then review stock, refund and due adjustments before confirming. Do not enter a separate negative sale or return more than the quantity sold.',
        answerBn:
            'মূল বিক্রয় খুলে পণ্য ফেরতের অপশন ব্যবহার করুন। ফেরত পণ্য ও পরিমাণ বেছে স্টক, টাকা ফেরত ও বাকির সমন্বয় দেখে নিশ্চিত করুন। আলাদা ঋণাত্মক বিক্রয় দেবেন না বা বিক্রির চেয়ে বেশি পণ্য ফেরত দেখাবেন না।',
      ),
      HelpFaqEntry(
        id: 'checkout-failed',
        questionEn: 'What should I do after a failed or uncertain checkout?',
        questionBn: 'চেকআউট ব্যর্থ হলে বা সংরক্ষণ নিয়ে সন্দেহ হলে কী করব?',
        answerEn:
            'Check sales history, stock and payment records first. If the sale already exists, do not create it again. Keep the invoice/reference and error details and contact support if totals disagree. Never uninstall the app to troubleshoot unsynced transactions.',
        answerBn:
            'আগে বিক্রয়ের ইতিহাস, স্টক ও পেমেন্ট দেখুন। বিক্রয় সংরক্ষিত থাকলে আবার তৈরি করবেন না। হিসাব না মিললে চালান/রেফারেন্স ও ত্রুটির তথ্য রেখে সাপোর্টে জানান। সিঙ্ক না হওয়া লেনদেনের সমস্যা সমাধানে অ্যাপ আনইনস্টল করবেন না।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'receipts',
    titleEn: 'Receipts, download & sharing',
    titleBn: 'রসিদ, ডাউনলোড ও শেয়ার',
    entries: [
      HelpFaqEntry(
        id: 'save-receipt',
        questionEn: 'Can I save a receipt while offline?',
        questionBn: 'অফলাইনে রসিদ সংরক্ষণ করতে পারব?',
        answerEn:
            'For a sale already saved on this phone, use Save to phone / Download to generate its receipt locally. Wait for the success/failure message. Downloading a receipt does not mean that the sale has synced to the server.',
        answerBn:
            'এই ফোনে সংরক্ষিত বিক্রয়ের রসিদ ফোনে সংরক্ষণ / ডাউনলোড দিয়ে তৈরি করতে পারেন। সফল বা ব্যর্থ হওয়ার বার্তা দেখুন। রসিদ ডাউনলোড হওয়া মানেই বিক্রয় সার্ভারে সিঙ্ক হয়েছে—এমন নয়।',
      ),
      HelpFaqEntry(
        id: 'find-download',
        questionEn: 'Where is my downloaded receipt or report?',
        questionBn: 'ডাউনলোড করা রসিদ বা রিপোর্ট কোথায় পাব?',
        answerEn:
            'Check the phone file manager and Downloads, or the location shown by the save dialog/message. The location can vary by Android version and export action. If saving fails, check available storage and any permission requested by the phone.',
        answerBn:
            'ফোনের ফাইল ম্যানেজারের Downloads বা সংরক্ষণের সময় দেখানো স্থানে দেখুন। Android সংস্করণ ও এক্সপোর্ট পদ্ধতি অনুযায়ী স্থান বদলাতে পারে। সংরক্ষণ না হলে খালি জায়গা ও ফোনে চাওয়া অনুমতি পরীক্ষা করুন।',
      ),
      HelpFaqEntry(
        id: 'invoice-share',
        questionEn:
            'Why do digital invoice and WhatsApp sharing need internet?',
        questionBn: 'ডিজিটাল চালান ও WhatsApp শেয়ারে ইন্টারনেট লাগে কেন?',
        answerEn:
            'A digital invoice link is issued by the server, so connect and sync the sale before requesting it. WhatsApp also needs connectivity to send a message. A locally saved PDF can be kept offline, but opening the share app does not guarantee delivery.',
        answerBn:
            'ডিজিটাল চালানের লিংক সার্ভার তৈরি করে; তাই ইন্টারনেটে যুক্ত হয়ে বিক্রয় সিঙ্কের পর লিংক তৈরি করুন। WhatsApp-এ বার্তা পাঠাতেও সংযোগ দরকার। PDF অফলাইনে রাখা যায়, কিন্তু শেয়ারের অ্যাপ খুললেই বার্তা পৌঁছেছে ধরে নেবেন না।',
      ),
      HelpFaqEntry(
        id: 'thermal-print',
        questionEn: 'Can I print the receipt on a small thermal printer?',
        questionBn: 'ছোট থার্মাল প্রিন্টারে রসিদ প্রিন্ট করা যাবে?',
        answerEn:
            'Use the thermal receipt/PDF option and the printing/share options supported by your phone and printer. Match the paper width and check a sample print. Printer connection, driver/app and paper-size compatibility depend on the printer; direct support for every Bluetooth printer is not guaranteed.',
        answerBn:
            'থার্মাল রসিদ/PDF ও ফোন–প্রিন্টারে থাকা প্রিন্ট/শেয়ার অপশন ব্যবহার করুন। কাগজের প্রস্থ মিলিয়ে পরীক্ষামূলক প্রিন্ট নিন। সংযোগ, ড্রাইভার/অ্যাপ ও কাগজের মাপ প্রিন্টারের ওপর নির্ভর করে; সব Bluetooth প্রিন্টারে সরাসরি কাজ করার নিশ্চয়তা নেই।',
      ),
      HelpFaqEntry(
        id: 'receipt-branding',
        questionEn: 'Which name appears at the top of my sales receipt?',
        questionBn: 'বিক্রয়ের রসিদের ওপরে কার নাম দেখাবে?',
        answerEn:
            'The header uses your saved shop information. Update the shop name and contact details before generating the receipt. Mohajon branding may appear in the footer; it does not replace your business name.',
        answerBn:
            'রসিদের শিরোনামে সংরক্ষিত দোকানের তথ্য ব্যবহার হয়। রসিদ তৈরির আগে দোকানের নাম ও যোগাযোগের তথ্য ঠিক রাখুন। ফুটারে মহাজনের পরিচয় থাকতে পারে; সেটি আপনার ব্যবসার নামের পরিবর্তে নয়।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'customers',
    titleEn: 'Customers, dues & loyalty',
    titleBn: 'গ্রাহক, বাকি ও লয়্যালটি',
    entries: [
      HelpFaqEntry(
        id: 'customer-photo',
        questionEn: 'How do I add a customer and their photo or logo?',
        questionBn: 'গ্রাহক ও তাঁর ছবি বা লোগো কীভাবে যোগ করব?',
        answerEn:
            'Open Clients and use Add / +. Enter the customer details and use the photo control to choose or capture an image. Save and sync when online. An image chosen on one phone must upload successfully before it can appear on another device.',
        answerBn:
            'গ্রাহক তালিকা থেকে যোগ করুন / + চাপুন। তথ্য লিখে ছবির অপশন দিয়ে গ্যালারি বা ক্যামেরা থেকে ছবি নিন। সংরক্ষণের পর অনলাইনে সিঙ্ক করুন। অন্য ডিভাইসে ছবি দেখতে এই ফোন থেকে সেটি সফলভাবে আপলোড হতে হবে।',
      ),
      HelpFaqEntry(
        id: 'customer-import',
        questionEn:
            'Can I import customers instead of entering everyone manually?',
        questionBn: 'সব গ্রাহক হাতে না লিখে ইমপোর্ট করতে পারব?',
        answerEn:
            'Use the import/contact action offered in the Clients screen. Allow contacts access only if you choose phone contacts, follow the displayed format for file import, and review the preview/duplicates before confirming.',
        answerBn:
            'গ্রাহক স্ক্রিনে থাকা ইমপোর্ট/কন্টাক্টের অপশন ব্যবহার করুন। ফোনের কন্টাক্ট নিলে তবেই তার অনুমতি দিন। ফাইল ইমপোর্টে দেখানো ফরম্যাট মেনে প্রিভিউ ও একই গ্রাহক একাধিক আছে কি না দেখে নিশ্চিত করুন।',
      ),
      HelpFaqEntry(
        id: 'customer-merge',
        questionEn: 'What should I do with duplicate customer records?',
        questionBn: 'একই গ্রাহকের একাধিক রেকর্ড থাকলে কী করব?',
        answerEn:
            'Compare phone numbers and statements first. Use the merge option where available and carefully choose the customer to keep. Do not delete one record merely because the names match; it may have sales, payments or dues linked to it.',
        answerBn:
            'আগে ফোন নম্বর ও হিসাব মিলিয়ে দেখুন। একত্র করার অপশন থাকলে কোন রেকর্ড রাখবেন তা সতর্কভাবে বেছে নিন। শুধু নাম এক বলে একটি মুছবেন না; তার সঙ্গে বিক্রয়, পেমেন্ট বা বাকি যুক্ত থাকতে পারে।',
      ),
      HelpFaqEntry(
        id: 'credit-limit',
        questionEn: 'How can I limit how much a customer buys on credit?',
        questionBn: 'একজন গ্রাহক কত টাকা বাকি নিতে পারবেন তা সীমিত করব কীভাবে?',
        answerEn:
            'Set the credit limit in the customer settings/form. A due sale may be blocked if it would exceed the available limit. Check the customer statement and sync before changing a limit just to bypass a warning.',
        answerBn:
            'গ্রাহকের ফর্ম/সেটিংসে বাকির সীমা নির্ধারণ করুন। নতুন বাকির কারণে সীমা পার হলে বিক্রয়ে বাধা আসতে পারে। সতর্কতা এড়াতে সীমা বাড়ানোর আগে গ্রাহকের হিসাব দেখুন ও সিঙ্ক করুন।',
      ),
      HelpFaqEntry(
        id: 'collect-due',
        questionEn: 'How do I collect a customer due payment?',
        questionBn: 'গ্রাহকের বাকি টাকা কীভাবে আদায় দেখাব?',
        answerEn:
            'Open the customer and choose Add payment / Collect due. Enter the amount actually received and payment method, linking the correct sale when required. Check the resulting statement instead of editing the original sale just to mark a payment.',
        answerBn:
            'গ্রাহক খুলে পেমেন্ট যোগ / বাকি আদায় বেছে নিন। বাস্তবে পাওয়া টাকা ও পেমেন্ট পদ্ধতি লিখুন; প্রয়োজন হলে সঠিক বিক্রয় যুক্ত করুন। টাকা পাওয়া দেখাতে পুরোনো বিক্রয় বদলানোর বদলে নতুন পেমেন্টের পর হিসাব দেখুন।',
      ),
      HelpFaqEntry(
        id: 'customer-statement',
        questionEn: 'Where do I see a customer ledger or outstanding balance?',
        questionBn: 'গ্রাহকের খাতা বা বকেয়া ব্যালেন্স কোথায় দেখব?',
        answerEn:
            'Open the customer profile or Customer ledger report to inspect sales and payments. Use matching dates and the correct branch when comparing totals. An invoice due, a customer balance and total sales describe different things and should not be treated as the same number.',
        answerBn:
            'গ্রাহকের প্রোফাইল বা গ্রাহকের খাতা রিপোর্টে বিক্রয় ও পেমেন্ট দেখুন। তুলনার সময় একই তারিখ ও সঠিক শাখা বেছে নিন। একটি চালানের বাকি, গ্রাহকের মোট বকেয়া ও মোট বিক্রয় আলাদা হিসাব—সবগুলো একই সংখ্যা নয়।',
      ),
      HelpFaqEntry(
        id: 'payment-methods',
        questionEn: 'How do I record cash, mobile banking or a wrong payment?',
        questionBn: 'নগদ, মোবাইল ব্যাংকিং বা ভুল পেমেন্ট কীভাবে রেকর্ড করব?',
        answerEn:
            'Choose an enabled payment method and add a reference when requested. Recording bKash or another method is a bookkeeping entry, not proof that money was transferred. For an incorrect payment, use the authorized correction/delete action and review the linked balance.',
        answerBn:
            'চালু পেমেন্ট পদ্ধতি বেছে প্রয়োজন হলে রেফারেন্স দিন। bKash বা অন্য পদ্ধতিতে টাকা রেকর্ড করা একটি হিসাবের এন্ট্রি; সেটি টাকা পাঠানোর প্রমাণ নয়। ভুল হলে অনুমোদিত সংশোধন/মুছে দেওয়ার অপশন ব্যবহার করে সংশ্লিষ্ট ব্যালেন্স দেখুন।',
      ),
      HelpFaqEntry(
        id: 'due-reminder',
        questionEn: 'How do due-recovery follow-ups and reminders help?',
        questionBn: 'বাকি আদায়ের ফলোআপ ও রিমাইন্ডার কীভাবে সাহায্য করে?',
        answerEn:
            'Use customer due/follow-up actions to plan collection and keep notes/status. Review the recipient and message before sharing. A reminder or follow-up does not collect money or automatically change the balance; record the payment after receiving it.',
        answerBn:
            'গ্রাহকের বাকি/ফলোআপ অপশন দিয়ে আদায়ের পরিকল্পনা, নোট ও অবস্থা রাখুন। শেয়ারের আগে প্রাপক ও বার্তা দেখুন। রিমাইন্ডার দিলেই টাকা আদায় বা ব্যালেন্স বদলে যায় না; টাকা পেলে পেমেন্ট রেকর্ড করুন।',
      ),
      HelpFaqEntry(
        id: 'customer-growth',
        questionEn: 'What is Grow customers used for?',
        questionBn: 'গ্রাহক বাড়ান ফিচার কী কাজে লাগে?',
        answerEn:
            'It highlights customers and practical follow-up opportunities based on recorded purchases. Check the suggested action and customer history before contacting anyone. Suggestions are guidance, not a promise of repeat sales.',
        answerBn:
            'সংরক্ষিত কেনাকাটা থেকে গ্রাহক ও ফলোআপের সুযোগ দেখায়। যোগাযোগের আগে প্রস্তাবিত কাজ ও গ্রাহকের ইতিহাস দেখুন। এগুলো পরামর্শ; আবার বিক্রয় হবে এমন নিশ্চয়তা নয়।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'suppliers',
    titleEn: 'Suppliers & purchases',
    titleBn: 'সরবরাহকারী ও কেনাকাটা',
    entries: [
      HelpFaqEntry(
        id: 'supplier-setup',
        questionEn: 'How do I add suppliers and choose their category?',
        questionBn: 'সরবরাহকারী ও তাঁদের ক্যাটাগরি কীভাবে যোগ করব?',
        answerEn:
            'Open Suppliers / Vendors from More and add the company/contact details. Choose a category relevant to your shop type and save. Keep the same supplier record for future purchases and payments so the ledger stays together.',
        answerBn:
            'আরও থেকে সরবরাহকারী খুলে প্রতিষ্ঠান ও যোগাযোগের তথ্য দিন। দোকানের ধরনের সঙ্গে মেলে এমন ক্যাটাগরি বেছে সংরক্ষণ করুন। পরের কেনাকাটা ও পেমেন্ট একই সরবরাহকারীর রেকর্ডে রাখলে হিসাব একসঙ্গে থাকবে।',
      ),
      HelpFaqEntry(
        id: 'purchase-stock',
        questionEn: 'How do I record purchased goods and increase stock?',
        questionBn: 'কেনা পণ্য রেকর্ড করে স্টক বাড়াব কীভাবে?',
        answerEn:
            'Use the product purchase/receive-goods workflow to select supplier, products, received quantities and costs. Review stock and payment details before saving. A supplier ledger amount alone is not a substitute for receiving item quantities into stock.',
        answerBn:
            'পণ্য কেনাকাটা/গ্রহণের ফ্লোতে সরবরাহকারী, পণ্য, পাওয়া পরিমাণ ও ক্রয়মূল্য দিন। সংরক্ষণের আগে স্টক ও পেমেন্ট দেখুন। শুধু সরবরাহকারীর খাতায় টাকার এন্ট্রি দিলেই পণ্যের পরিমাণসহ স্টক গ্রহণ করা হয় না।',
      ),
      HelpFaqEntry(
        id: 'supplier-payment',
        questionEn: 'Where do I record supplier bills and payments?',
        questionBn: 'সরবরাহকারীর বিল ও পেমেন্ট কোথায় রাখব?',
        answerEn:
            'Open the supplier profile to record purchases and money paid, then check the supplier ledger and outstanding amount. Enter actual payments once, using notes/references where available, and keep the purchase and payment dates correct.',
        answerBn:
            'সরবরাহকারীর প্রোফাইলে কেনাকাটা ও দেওয়া টাকা রেকর্ড করে খাতা ও বকেয়া দেখুন। বাস্তবে দেওয়া টাকা একবারই লিখুন, সুযোগ থাকলে নোট/রেফারেন্স দিন এবং ক্রয়–পেমেন্টের তারিখ ঠিক রাখুন।',
      ),
      HelpFaqEntry(
        id: 'purchase-planner',
        questionEn: 'What does the purchase planner recommend?',
        questionBn: 'ক্রয় পরিকল্পনা কী ধরনের পরামর্শ দেয়?',
        answerEn:
            'It uses recorded sales, available stock and purchase history to suggest restocking quantities and suppliers. Check actual demand, supplier lead time and available cash before creating an order. Recommendations do not place an order by themselves.',
        answerBn:
            'বিক্রয়, বর্তমান স্টক ও ক্রয়ের ইতিহাস থেকে পুনরায় পণ্য আনার পরিমাণ ও সরবরাহকারীর পরামর্শ দেয়। অর্ডারের আগে বাস্তব চাহিদা, পণ্য আসার সময় ও হাতে থাকা টাকা দেখুন। পরামর্শ দেখালেই নিজে থেকে অর্ডার হয় না।',
      ),
      HelpFaqEntry(
        id: 'partial-receipt',
        questionEn: 'How do I receive only part of a purchase order?',
        questionBn: 'ক্রয় অর্ডারের কিছু পণ্য এলে কীভাবে গ্রহণ দেখাব?',
        answerEn:
            'Open the order and record a receipt for only the quantities actually received. Keep the remaining quantities pending and compare receipt history before adding another receipt. Order/receipt actions that use the server require internet.',
        answerBn:
            'অর্ডার খুলে যত পণ্য বাস্তবে পেয়েছেন শুধু সেটুকুর গ্রহণ রসিদ দিন। বাকি পরিমাণ অপেক্ষমাণ রাখুন এবং পরের রসিদ দেওয়ার আগে আগের গ্রহণের ইতিহাস দেখুন। সার্ভার-নির্ভর অর্ডার/গ্রহণে ইন্টারনেট দরকার।',
      ),
      HelpFaqEntry(
        id: 'supplier-return',
        questionEn: 'How do I record goods returned to a supplier?',
        questionBn: 'সরবরাহকারীকে পণ্য ফেরত দিলে কীভাবে লিখব?',
        answerEn:
            'Use the supplier-return action linked to the relevant purchase/receipt where available. Confirm the items, quantities and financial adjustment. Check stock and supplier dues afterward; returning goods and receiving a cash refund are not always the same event.',
        answerBn:
            'সংশ্লিষ্ট কেনাকাটা/গ্রহণের সঙ্গে যুক্ত সরবরাহকারীকে ফেরত দেওয়ার অপশন ব্যবহার করুন। পণ্য, পরিমাণ ও টাকার সমন্বয় নিশ্চিত করে স্টক ও সরবরাহকারীর বাকি মিলিয়ে নিন। পণ্য ফেরত ও নগদ টাকা ফেরত পাওয়া সবসময় একই ঘটনা নয়।',
      ),
      HelpFaqEntry(
        id: 'purchase-proof',
        questionEn: 'Can I keep a purchase invoice or receipt image?',
        questionBn: 'কেনাকাটার চালান বা রসিদের ছবি রাখতে পারব?',
        answerEn:
            'Use the attachment option offered by the purchase/order/receipt form. Add a readable image and wait for upload confirmation when online. Keep the original until the attachment and related purchase are safely saved and synced.',
        answerBn:
            'কেনাকাটা/অর্ডার/গ্রহণের ফর্মে সংযুক্তির অপশন থাকলে পরিষ্কার ছবি দিন। অনলাইনে আপলোডের নিশ্চিত বার্তা দেখুন। ছবি ও সংশ্লিষ্ট কেনাকাটা নিরাপদে সংরক্ষণ–সিঙ্ক হওয়া পর্যন্ত মূল কাগজ রেখে দিন।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'reports',
    titleEn: 'Expenses, day closing & reports',
    titleBn: 'খরচ, দিনশেষ ও রিপোর্ট',
    entries: [
      HelpFaqEntry(
        id: 'expenses',
        questionEn: 'How do I record business expenses?',
        questionBn: 'ব্যবসার খরচ কীভাবে লিখব?',
        answerEn:
            'Open Expenses from More, add the amount, category, date and description, then save. Use expenses for business costs; customer collections, supplier payments and investor payouts have their own workflows and should not be entered twice.',
        answerBn:
            'আরও থেকে খরচে গিয়ে টাকা, ক্যাটাগরি, তারিখ ও বিবরণ দিয়ে সংরক্ষণ করুন। ব্যবসার খরচ এখানে লিখুন। গ্রাহকের টাকা আদায়, সরবরাহকারীর পেমেন্ট ও বিনিয়োগকারীর টাকা দেওয়ার আলাদা ফ্লো আছে; একই টাকা দুবার লিখবেন না।',
      ),
      HelpFaqEntry(
        id: 'day-closing',
        questionEn: 'What do I enter when closing the business day?',
        questionBn: 'ব্যবসার দিন বন্ধ করার সময় কী দেব?',
        answerEn:
            'Open Day closing, review the opening/expected cash and enter the physical cash you actually counted. Add a note for any difference, then submit when online. Count cash separately from mobile banking/bank balances.',
        answerBn:
            'দিনশেষে শুরুর ও প্রত্যাশিত নগদ হিসাব দেখে বাস্তবে গুনে পাওয়া নগদ লিখুন। পার্থক্য থাকলে নোট দিয়ে অনলাইনে জমা দিন। মোবাইল ব্যাংকিং বা ব্যাংকের ব্যালেন্সকে হাতে থাকা নগদ হিসেবে গুনবেন না।',
      ),
      HelpFaqEntry(
        id: 'cash-variance',
        questionEn: 'Why does actual cash differ from expected cash?',
        questionBn: 'বাস্তব নগদ ও প্রত্যাশিত নগদ আলাদা দেখায় কেন?',
        answerEn:
            'Review opening cash, cash sales, due collections, expenses, refunds and other recorded cash movements for that day/branch. Check for missing or duplicate entries and payments recorded under the wrong method before making a correction.',
        answerBn:
            'সেদিনের ও সেই শাখার শুরুর নগদ, নগদ বিক্রয়, বাকি আদায়, খরচ, টাকা ফেরত ও অন্য নগদ লেনদেন দেখুন। কোনো এন্ট্রি বাদ/দুবার হয়েছে বা পেমেন্টের পদ্ধতি ভুল হয়েছে কি না দেখে সংশোধন করুন।',
      ),
      HelpFaqEntry(
        id: 'report-types',
        questionEn: 'Which reports can I view?',
        questionBn: 'কোন কোন রিপোর্ট দেখতে পারি?',
        answerEn:
            'Open Reports to find sales summary, Income Statement (profit/loss), Balance Sheet, Financial accounts, product sales, inventory, expenses, customer ledger, dues, payments, daily transactions and VAT. Financial accounts are owner-only and require branch-specific setup for full server statements.',
        answerBn:
            'রিপোর্টে বিক্রয় সারসংক্ষেপ, আয় বিবরণী (লাভ–ক্ষতি), আর্থিক অবস্থার বিবরণী, আর্থিক হিসাব, পণ্য বিক্রয়, মজুত, খরচ, গ্রাহকের খাতা, বাকি, পেমেন্ট, দৈনিক লেনদেন ও ভ্যাট দেখুন। পূর্ণ সার্ভারভিত্তিক আর্থিক বিবরণীর জন্য মালিককে শাখাভিত্তিক হিসাব সেটআপ করতে হবে।',
      ),
      HelpFaqEntry(
        id: 'accounting-opening',
        questionEn: 'How do I set up opening balances safely?',
        questionBn: 'প্রারম্ভিক হিসাব কীভাবে নিরাপদে সেটআপ করব?',
        answerEn:
            'As the owner, open Reports > Financial accounts, select the branch and choose the accounting start date. Enter the actual balances immediately before that date, including cash, inventory at book cost, receivables, assets, debts and equity. Assets must equal liabilities plus equity; the app never invents capital to fill a gap. Confirm carefully: setup is locked and older transactions are not posted again.',
        answerBn:
            'মালিক হিসেবে রিপোর্ট > আর্থিক হিসাব খুলে শাখা ও হিসাব শুরুর তারিখ বাছুন। তারিখটির ঠিক আগের আসল নগদ, বহিমূল্যে মজুত, পাওনা, সম্পদ, দেনা ও মূলধন লিখুন। সম্পদ অবশ্যই দায় ও মালিকানার যোগফলের সমান হবে; অমিল মেটাতে অ্যাপ নিজে মূলধন বানাবে না। ভালো করে নিশ্চিত করুন: সেটআপ লক থাকবে এবং আগের লেনদেন আবার যোগ হবে না।',
      ),
      HelpFaqEntry(
        id: 'accounting-finance',
        questionEn: 'How do I record capital, loans, assets and depreciation?',
        questionBn: 'মূলধন, ঋণ, সম্পদ ও অবচয় কীভাবে লিখব?',
        answerEn:
            'Use Add financial transaction after opening setup. Record owner contributions and withdrawals separately from sales, split loan repayment principal from interest, and record fixed-asset purchases and actual depreciation against an asset. Depreciation is not estimated automatically. Corrections use a reversal with history rather than silently overwriting a posted transaction.',
        answerBn:
            'প্রারম্ভিক সেটআপের পরে আর্থিক লেনদেন যোগ করুন ব্যবহার করুন। মালিকের জমা ও উত্তোলন বিক্রয় থেকে আলাদা রাখুন, ঋণের আসল ও সুদ আলাদা লিখুন এবং স্থায়ী সম্পদ কেনা ও সেই সম্পদের আসল অবচয় রেকর্ড করুন। অ্যাপ নিজে অবচয় অনুমান করে না। সংরক্ষিত লেনদেন চুপিসারে বদলানোর বদলে ইতিহাসসহ বিপরীত এন্ট্রি দিয়ে সংশোধন হয়।',
      ),
      HelpFaqEntry(
        id: 'accounting-quality',
        questionEn: 'Why does a balanced statement still say Needs review?',
        questionBn: 'হিসাব মেলার পরও যাচাই প্রয়োজন দেখায় কেন?',
        answerEn:
            'A balanced accounting equation does not prove every source is complete. Review missing payment evidence, supplier/investor classifications, unexpected negative balances and inventory-cost differences in Financial accounts. Confirm only additional historical receipts not already covered by payment records. Statements are management reports, not audited accounts or certified tax filings.',
        answerBn:
            'হিসাবের সমীকরণ মিললেই সব মূল রেকর্ড সম্পূর্ণ প্রমাণ হয় না। আর্থিক হিসাবে বাদ পড়া পেমেন্টের প্রমাণ, সরবরাহকারী/বিনিয়োগের শ্রেণি, অপ্রত্যাশিত ঋণাত্মক ব্যালেন্স ও মজুতের খরচের অমিল যাচাই করুন। পেমেন্ট রেকর্ডে থাকা টাকার বাইরে অতিরিক্ত পুরোনো আদায়ই নিশ্চিত করুন। এগুলো ব্যবস্থাপনার রিপোর্ট, নিরীক্ষিত হিসাব বা প্রত্যয়িত কর দাখিল নয়।',
      ),
      HelpFaqEntry(
        id: 'accounting-offline',
        questionEn: 'Can I use financial accounts offline?',
        questionBn: 'অফলাইনে আর্থিক হিসাব ব্যবহার করা যায়?',
        answerEn:
            'Previously loaded statements can be viewed as dated cached snapshots. New financial transactions can queue on the phone with a stable ID, then sync after ordinary sales and payments. Pending entries are not final server balances. Setup, classification and reversals need internet; failed validation remains available for correction. Without setup, Income Statement is clearly marked as an incomplete local estimate, and no Balance Sheet is invented.',
        answerBn:
            'আগে দেখা বিবরণী তারিখসহ সংরক্ষিত কপি হিসেবে অফলাইনে দেখা যায়। নতুন আর্থিক লেনদেন একই পরিচিতি রেখে ফোনে অপেক্ষায় থাকতে পারে এবং সাধারণ বিক্রয়-পেমেন্টের পরে সিঙ্ক হবে। অপেক্ষমাণ এন্ট্রি সার্ভারের চূড়ান্ত ব্যালেন্স নয়। সেটআপ, শ্রেণি যাচাই ও বিপরীত এন্ট্রিতে ইন্টারনেট লাগে; ভুল তথ্য সংশোধনের জন্য থেকে যায়। সেটআপ না থাকলে আয় বিবরণী অসম্পূর্ণ স্থানীয় অনুমান হিসেবে দেখায়, আর আর্থিক অবস্থার বিবরণী বানিয়ে দেখায় না।',
      ),
      HelpFaqEntry(
        id: 'report-dates',
        questionEn: 'How do I compare sales over six months or a year?',
        questionBn: 'ছয় মাস বা এক বছরের বিক্রয় কীভাবে তুলনা করব?',
        answerEn:
            'Use the date-range controls in Sales overview or the relevant report. Select the available month/year/custom range and inspect the graph and comparison values. Use the same branch and date range when comparing two reports; online aggregate views may need internet.',
        answerBn:
            'বিক্রয় পর্যালোচনা বা সংশ্লিষ্ট রিপোর্টের তারিখের অপশন থেকে মাস/বছর/নিজের সময়সীমা বেছে গ্রাফ ও তুলনা দেখুন। দুটি রিপোর্ট মেলাতে একই শাখা ও সময়সীমা দিন। সার্ভার থেকে সমন্বিত হিসাব দেখতে ইন্টারনেট লাগতে পারে।',
      ),
      HelpFaqEntry(
        id: 'sales-profit',
        questionEn: 'Why are sales, profit and cash received different?',
        questionBn: 'বিক্রয়, লাভ ও হাতে পাওয়া টাকা আলাদা কেন?',
        answerEn:
            'Sales are invoice values; money received depends on actual payments and dues. Profit also depends on recorded purchase costs, discounts, returns and the report definition. Incorrect/missing costs or different date filters can make comparisons misleading.',
        answerBn:
            'বিক্রয় হলো চালানের মূল্য; হাতে পাওয়া টাকা আসল পেমেন্ট ও বাকির ওপর নির্ভর করে। লাভে ক্রয়মূল্য, ছাড়, ফেরত ও রিপোর্টের হিসাবের ধরনও প্রভাব ফেলে। ভুল/বাদ পড়া ক্রয়মূল্য বা আলাদা তারিখে তুলনা করলে গরমিল মনে হতে পারে।',
      ),
      HelpFaqEntry(
        id: 'report-export',
        questionEn: 'Can I export reports in Bangla and English?',
        questionBn: 'বাংলা ও ইংরেজিতে রিপোর্ট এক্সপোর্ট করতে পারব?',
        answerEn:
            'Choose the app/report language and use the PDF or Excel export action available on that report. Names remain as entered. If Bangla looks broken in a viewer, try another PDF viewer and send support the report type, app version and a screenshot rather than changing the original records.',
        answerBn:
            'অ্যাপ/রিপোর্টের ভাষা বেছে সংশ্লিষ্ট রিপোর্টে থাকা PDF বা Excel এক্সপোর্ট ব্যবহার করুন। নাম আপনার লেখা ভাষাতেই থাকে। কোনো ভিউয়ারে বাংলা ভাঙলে অন্য PDF ভিউয়ার দিয়ে দেখুন এবং মূল রেকর্ড না বদলে রিপোর্টের ধরন, অ্যাপের সংস্করণ ও ছবি সাপোর্টে দিন।',
      ),
      HelpFaqEntry(
        id: 'report-mismatch',
        questionEn: 'What should I check if a report total looks wrong?',
        questionBn: 'রিপোর্টের হিসাব ভুল মনে হলে কী পরীক্ষা করব?',
        answerEn:
            'Compare date range, branch, sale/payment status, returns, deleted entries and sync status. An offline report may only include records stored on that phone. Sync and compare the underlying transactions; report the discrepancy instead of adding balancing entries without evidence.',
        answerBn:
            'তারিখ, শাখা, বিক্রয়/পেমেন্টের অবস্থা, ফেরত, মুছে দেওয়া এন্ট্রি ও সিঙ্ক পরীক্ষা করুন। অফলাইন রিপোর্টে শুধু এই ফোনে থাকা রেকর্ড থাকতে পারে। সিঙ্ক করে মূল লেনদেন মিলিয়ে দেখুন; প্রমাণ ছাড়া হিসাব মেলাতে নতুন এন্ট্রি না দিয়ে গরমিল জানান।',
      ),
      HelpFaqEntry(
        id: 'business-insights',
        questionEn:
            'What are Business health, advice, guardian and cash-flow insights?',
        questionBn:
            'ব্যবসার স্বাস্থ্য, পরামর্শ, নজরদারি ও নগদ প্রবাহ কী কাজে লাগে?',
        answerEn:
            'These views summarize recorded business activity and highlight trends, risks or suggested actions. Their quality depends on complete, correctly dated and synced records. Review source transactions before acting; an insight is not a guaranteed forecast or an automatic business decision.',
        answerBn:
            'এগুলো সংরক্ষিত ব্যবসার কাজ থেকে সারাংশ, প্রবণতা, ঝুঁকি বা করণীয় দেখায়। সঠিক ফলের জন্য সম্পূর্ণ, সঠিক তারিখের ও সিঙ্ক হওয়া রেকর্ড দরকার। সিদ্ধান্তের আগে মূল লেনদেন দেখুন; পরামর্শ নিশ্চিত ভবিষ্যদ্বাণী বা স্বয়ংক্রিয় সিদ্ধান্ত নয়।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'team',
    titleEn: 'Staff, branches & investments',
    titleBn: 'স্টাফ, শাখা ও বিনিয়োগ',
    entries: [
      HelpFaqEntry(
        id: 'staff-access',
        questionEn: 'How do I give staff access?',
        questionBn: 'স্টাফকে অ্যাক্সেস কীভাবে দেব?',
        answerEn:
            'As an authorized owner, open More → Staff and add the member using the available account/permission steps. Give only the access needed for that job. Staff should use their own account rather than the owner password.',
        answerBn:
            'অনুমতিপ্রাপ্ত মালিক হিসেবে আরও → স্টাফ খুলে অ্যাকাউন্ট/অনুমতির ধাপ মেনে সদস্য যোগ করুন। কাজের জন্য যতটুকু দরকার ততটুকু অনুমতি দিন। স্টাফকে মালিকের পাসওয়ার্ড না দিয়ে তাঁর নিজের অ্যাকাউন্ট ব্যবহার করতে দিন।',
      ),
      HelpFaqEntry(
        id: 'staff-permissions',
        questionEn: 'Why can staff not edit or delete some records?',
        questionBn: 'স্টাফ কিছু তথ্য সম্পাদনা বা মুছতে পারছেন না কেন?',
        answerEn:
            'Permissions and owner-only rules restrict sensitive actions. Ask the owner to review the staff role and access settings. Hiding or showing a button does not replace server authorization, and changing app language will not change permissions.',
        answerBn:
            'অনুমতি ও শুধু মালিকের জন্য রাখা নিয়মে গুরুত্বপূর্ণ কাজ সীমিত থাকে। মালিককে স্টাফের ভূমিকা ও অনুমতি দেখতে বলুন। শুধু বোতাম দেখা/না দেখা সার্ভারের অনুমতির বিকল্প নয়; ভাষা বদলালেও অনুমতি বদলায় না।',
      ),
      HelpFaqEntry(
        id: 'audit-history',
        questionEn: 'Where can I see who changed business records?',
        questionBn: 'ব্যবসার তথ্য কে বদলেছেন তা কোথায় দেখব?',
        answerEn:
            'Open Business activity history / Audit history from More when you have access. Review available actor, action, time and branch details. The history reflects events the system records; keep receipts and source documents for reconciliation too.',
        answerBn:
            'অনুমতি থাকলে আরও থেকে ব্যবসার কাজের ইতিহাস খুলুন। কর্তা, কাজ, সময় ও শাখার তথ্য দেখুন। সিস্টেমে রেকর্ড হওয়া কাজই ইতিহাসে থাকে; হিসাব মেলাতে রসিদ ও মূল কাগজও রাখুন।',
      ),
      HelpFaqEntry(
        id: 'branches',
        questionEn: 'How do I create or switch a branch?',
        questionBn: 'নতুন শাখা তৈরি বা শাখা পরিবর্তন করব কীভাবে?',
        answerEn:
            'Open More → Branches while online. Use an authorized account with the required Business entitlement to create a branch or select one you can access. Check the active branch before entering products, sales, payments or reports.',
        answerBn:
            'অনলাইনে আরও → শাখা খুলুন। প্রয়োজনীয় Business সুবিধা ও অনুমতিযুক্ত অ্যাকাউন্ট দিয়ে শাখা তৈরি বা প্রবেশযোগ্য শাখা নির্বাচন করুন। পণ্য, বিক্রয়, পেমেন্ট বা রিপোর্টের আগে নির্বাচিত শাখা দেখুন।',
      ),
      HelpFaqEntry(
        id: 'branch-isolation',
        questionEn: 'Why do stock and sales change when I switch branches?',
        questionBn: 'শাখা বদলালে স্টক ও বিক্রয় বদলে যায় কেন?',
        answerEn:
            'Branch-specific records belong to the selected branch. Switching branches is not a stock transfer. If something appears missing, check shop/branch, filters and sync before re-entering the transaction.',
        answerBn:
            'শাখাভিত্তিক রেকর্ড নির্বাচিত শাখার জন্য দেখায়। শাখা বদলানো মানে স্টক স্থানান্তর করা নয়। তথ্য না পেলে আবার এন্ট্রি দেওয়ার আগে দোকান/শাখা, ফিল্টার ও সিঙ্ক দেখুন।',
      ),
      HelpFaqEntry(
        id: 'investors',
        questionEn: 'How do I record investors and investments?',
        questionBn: 'বিনিয়োগকারী ও বিনিয়োগ কীভাবে লিখব?',
        answerEn:
            'Add the investor from Investors, then record the investment with the appropriate category, amount, dates and participating members. Review the agreement and entered shares before saving. These records track your business arrangement; they do not transfer money.',
        answerBn:
            'বিনিয়োগকারী থেকে সদস্য যোগ করে বিনিয়োগে ক্যাটাগরি, টাকা, তারিখ ও অংশগ্রহণকারীর তথ্য দিন। সংরক্ষণের আগে চুক্তি ও অংশের হিসাব দেখুন। এগুলো ব্যবসার চুক্তির হিসাব রাখে; টাকা স্থানান্তর করে না।',
      ),
      HelpFaqEntry(
        id: 'investor-payout',
        questionEn:
            'How do I track investor profit, payouts and outstanding amounts?',
        questionBn: 'বিনিয়োগকারীর লাভ, পরিশোধ ও বকেয়া কীভাবে দেখব?',
        answerEn:
            'Use the investment detail and investor reports to review profit allocations, outstanding amounts and payout history. Record a payout only after the real payment, under the correct investor/investment. Check figures and terms before confirming.',
        answerBn:
            'বিনিয়োগের বিস্তারিত ও বিনিয়োগকারীর রিপোর্টে লাভের ভাগ, বকেয়া ও পরিশোধের ইতিহাস দেখুন। বাস্তবে টাকা দেওয়ার পর সঠিক বিনিয়োগকারী/বিনিয়োগে পরিশোধ লিখুন। নিশ্চিত করার আগে হিসাব ও শর্ত মিলিয়ে নিন।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'subscription',
    titleEn: 'Plans, payments & AI credits',
    titleBn: 'প্ল্যান, পেমেন্ট ও AI ক্রেডিট',
    entries: [
      HelpFaqEntry(
        id: 'current-plan',
        questionEn: 'Where do I see my trial, plan limits and renewal date?',
        questionBn: 'ট্রায়াল, প্ল্যানের সীমা ও নবায়নের তারিখ কোথায় দেখব?',
        answerEn:
            'Open My profile → Subscription to see the status, available plans, included features and dates returned for your account. Check that screen for current prices and allowances instead of relying on old screenshots or fixed numbers in help text.',
        answerBn:
            'আমার প্রোফাইল → সাবস্ক্রিপশনে অ্যাকাউন্টের অবস্থা, প্ল্যান, সুবিধা ও তারিখ দেখুন। বর্তমান মূল্য ও বরাদ্দ ওই স্ক্রিন থেকেই মিলিয়ে নিন; পুরোনো ছবি বা সাহায্যের লেখায় নির্দিষ্ট সংখ্যা ধরে নেবেন না।',
      ),
      HelpFaqEntry(
        id: 'business-plan',
        questionEn: 'Why does a feature ask for the Business plan?',
        questionBn: 'কোনো ফিচারে Business প্ল্যান চাইছে কেন?',
        answerEn:
            'Some features, such as branch management, require a specific entitlement as well as the right role. Review plan features on Subscription and reconnect to refresh your status after an upgrade. Retrying a restricted action is not a valid way to unlock it.',
        answerBn:
            'শাখা পরিচালনার মতো কিছু ফিচারে সঠিক ভূমিকার পাশাপাশি নির্দিষ্ট প্ল্যানের সুবিধা দরকার। সাবস্ক্রিপশনে সুবিধা দেখুন এবং আপগ্রেডের পর অনলাইনে অবস্থা হালনাগাদ করুন। বারবার চেষ্টা করে সীমাবদ্ধ ফিচার খুলে নেওয়া বৈধ পদ্ধতি নয়।',
      ),
      HelpFaqEntry(
        id: 'subscription-payment',
        questionEn: 'How do I purchase or renew a subscription?',
        questionBn: 'সাবস্ক্রিপশন কিনব বা নবায়ন করব কীভাবে?',
        answerEn:
            'Select a plan on Subscription and follow the payment method offered there while online. Check the plan, price and merchant details before approving. Payment options depend on the current service setup; recording a shop payment manually does not activate a subscription.',
        answerBn:
            'অনলাইনে সাবস্ক্রিপশন থেকে প্ল্যান বেছে সেখানে দেওয়া পেমেন্টের ধাপ অনুসরণ করুন। অনুমোদনের আগে প্ল্যান, মূল্য ও মার্চেন্টের তথ্য দেখুন। পেমেন্ট অপশন বর্তমান সেবার সেটআপের ওপর নির্ভর করে; দোকানের খাতায় নিজে পেমেন্ট লিখলে সাবস্ক্রিপশন চালু হয় না।',
      ),
      HelpFaqEntry(
        id: 'payment-pending',
        questionEn:
            'Money was deducted but my plan is not active. What should I do?',
        questionBn: 'টাকা কেটেছে কিন্তু প্ল্যান চালু হয়নি—কী করব?',
        answerEn:
            'Keep the transaction/reference number and check payment/status history after reconnecting. Do not pay again immediately. Contact support with the plan, time and transaction reference if it remains pending; never send your payment PIN, password or OTP.',
        answerBn:
            'লেনদেন/রেফারেন্স নম্বর রেখে পুনরায় অনলাইনে পেমেন্ট ও সাবস্ক্রিপশনের অবস্থা দেখুন। সঙ্গে সঙ্গে আবার টাকা দেবেন না। অপেক্ষমাণ থাকলে প্ল্যান, সময় ও রেফারেন্সসহ সাপোর্টে জানান; পেমেন্ট PIN, পাসওয়ার্ড বা OTP পাঠাবেন না।',
      ),
      HelpFaqEntry(
        id: 'expired-plan',
        questionEn: 'What happens when my trial or subscription expires?',
        questionBn: 'ট্রায়াল বা সাবস্ক্রিপশনের মেয়াদ শেষ হলে কী হবে?',
        answerEn:
            'Check Subscription for the latest status and renewal options. Access to plan-controlled actions is determined by your current entitlement and server checks. Expiry is not a reason to delete the app or business records; sync/export your data and ask support about access if needed.',
        answerBn:
            'সর্বশেষ অবস্থা ও নবায়নের অপশন সাবস্ক্রিপশনে দেখুন। প্ল্যানভিত্তিক কাজের অনুমতি বর্তমান সুবিধা ও সার্ভারের যাচাইয়ের ওপর নির্ভর করে। মেয়াদ শেষ মানেই অ্যাপ বা ব্যবসার তথ্য মুছে ফেলা নয়; সিঙ্ক/এক্সপোর্ট করে প্রয়োজনে অ্যাক্সেস নিয়ে সাপোর্টে জানান।',
      ),
      HelpFaqEntry(
        id: 'ai-credits',
        questionEn: 'Where can I check welcome and monthly AI credits?',
        questionBn: 'স্বাগতম ও মাসিক AI ক্রেডিট কোথায় দেখব?',
        answerEn:
            'Check the AI-credit section of Subscription while online. Welcome and monthly allowances may be shown separately and depend on account/plan rules. Refresh after a conversation; if usage does not update, note the conversation time and report it rather than assuming unlimited free use.',
        answerBn:
            'অনলাইনে সাবস্ক্রিপশনের AI ক্রেডিট অংশ দেখুন। স্বাগতম ও মাসিক বরাদ্দ আলাদা হতে পারে এবং অ্যাকাউন্ট/প্ল্যানের নিয়মে নির্ধারিত হয়। কথোপকথনের পর হালনাগাদ করুন; ব্যবহার না বদলালে অসীম ফ্রি ধরে না নিয়ে সময়সহ সাপোর্টে জানান।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'ai',
    titleEn: 'Mohajon AI & voice',
    titleBn: 'মহাজন AI ও ভয়েস',
    entries: [
      HelpFaqEntry(
        id: 'ai-use',
        questionEn: 'What can I ask Mohajon AI?',
        questionBn: 'মহাজন AI-কে কী জিজ্ঞেস করতে পারি?',
        answerEn:
            'Ask about your shop, recorded sales/stock/dues or practical business questions. Give a clear question and time period where relevant. Answers depend on accessible data and provider availability; verify important figures in the source reports.',
        answerBn:
            'দোকান, সংরক্ষিত বিক্রয়/স্টক/বাকি বা ব্যবসার বাস্তব প্রশ্ন করতে পারেন। প্রয়োজন হলে সময়সীমাসহ পরিষ্কার প্রশ্ন করুন। উত্তর প্রবেশযোগ্য তথ্য ও AI সেবার প্রাপ্যতার ওপর নির্ভর করে; গুরুত্বপূর্ণ হিসাব মূল রিপোর্টে মিলিয়ে নিন।',
      ),
      HelpFaqEntry(
        id: 'ai-language',
        questionEn: 'Can I ask in Bangla while using the English app?',
        questionBn: 'ইংরেজি অ্যাপ ব্যবহার করেও বাংলায় AI-কে প্রশ্ন করতে পারব?',
        answerEn:
            'Yes. Write the question in Bangla or English and tell the assistant which language you want for the reply. Changing the interface language does not prevent you from using the other language in a prompt.',
        answerBn:
            'হ্যাঁ। বাংলা বা ইংরেজিতে প্রশ্ন লিখে কোন ভাষায় উত্তর চান তা বলতে পারেন। অ্যাপের ভাষা আলাদা হলেও অন্য ভাষায় প্রশ্ন করতে বাধা নেই।',
      ),
      HelpFaqEntry(
        id: 'voice-billing',
        questionEn: 'How do I use voice billing safely?',
        questionBn: 'ভয়েস দিয়ে নিরাপদে বিল করব কীভাবে?',
        answerEn:
            'Open the voice-billing action, allow microphone access and speak clearly. Use internet for AI matching, then review matched products, whole-number quantities and prices before adding them to the cart. Voice recognition can make mistakes; it is not a completed sale until checkout succeeds.',
        answerBn:
            'ভয়েস বিলের অপশন খুলে মাইক্রোফোনের অনুমতি দিয়ে পরিষ্কার বলুন। AI দিয়ে মেলাতে ইন্টারনেট দরকার। কার্টে নেওয়ার আগে পণ্য, পূর্ণ সংখ্যার পরিমাণ ও দাম দেখুন। কথার ভুল শনাক্তকরণ হতে পারে; চেকআউট সফল না হওয়া পর্যন্ত বিক্রয় শেষ নয়।',
      ),
      HelpFaqEntry(
        id: 'ai-failure',
        questionEn: 'Why is AI or voice not responding?',
        questionBn: 'AI বা ভয়েস উত্তর দিচ্ছে না কেন?',
        answerEn:
            'Check internet, available AI credits and microphone permission for voice. The server/provider may also be unavailable or rate-limited. Retry later and send support the time and visible error if it continues. Do not paste API keys or business passwords into a question.',
        answerBn:
            'ইন্টারনেট, AI ক্রেডিট ও ভয়েসের জন্য মাইক্রোফোনের অনুমতি দেখুন। সার্ভার/AI সেবা বন্ধ বা অনুরোধের সীমা পূর্ণও হতে পারে। পরে চেষ্টা করুন এবং চলতে থাকলে সময় ও দৃশ্যমান ত্রুটি সাপোর্টে দিন। প্রশ্নে API key বা ব্যবসার পাসওয়ার্ড দেবেন না।',
      ),
      HelpFaqEntry(
        id: 'ai-actions',
        questionEn: 'Does an AI answer automatically change my records?',
        questionBn: 'AI-এর উত্তর কি নিজে থেকে ব্যবসার তথ্য বদলে দেয়?',
        answerEn:
            'A chat answer or suggestion is not proof that a transaction was saved. Review any proposed action and use its confirmation/checkout workflow. For important decisions, check the original records and seek qualified advice when appropriate.',
        answerBn:
            'চ্যাটের উত্তর বা পরামর্শ কোনো লেনদেন সংরক্ষণের প্রমাণ নয়। প্রস্তাবিত কাজ দেখে তার নিশ্চিতকরণ/চেকআউটের ধাপ সম্পন্ন করুন। গুরুত্বপূর্ণ সিদ্ধান্তে মূল তথ্য যাচাই করুন এবং প্রয়োজনে সংশ্লিষ্ট বিশেষজ্ঞের পরামর্শ নিন।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'offline',
    titleEn: 'Offline, sync & backup',
    titleBn: 'অফলাইন, সিঙ্ক ও ব্যাকআপ',
    entries: [
      HelpFaqEntry(
        id: 'offline-work',
        questionEn: 'What can I do without internet?',
        questionBn: 'ইন্টারনেট ছাড়া কী কী করতে পারব?',
        answerEn:
            'After online sign-in/setup, supported local product, customer and sales workflows can use records already stored on this phone. Offline access also depends on your session, permissions and cached plan state. Data not yet downloaded and server-only features are unavailable offline.',
        answerBn:
            'অনলাইনে লগইন/সেটআপের পর সমর্থিত পণ্য, গ্রাহক ও বিক্রয়ের কাজ এই ফোনে থাকা তথ্য দিয়ে করা যায়। অফলাইন ব্যবহার সেশন, অনুমতি ও সংরক্ষিত প্ল্যানের অবস্থার ওপরও নির্ভর করে। আগে ডাউনলোড না হওয়া তথ্য ও শুধু সার্ভার-নির্ভর ফিচার অফলাইনে চলে না।',
      ),
      HelpFaqEntry(
        id: 'online-only',
        questionEn: 'Which actions require an internet connection?',
        questionBn: 'কোন কাজগুলোতে ইন্টারনেট দরকার?',
        answerEn:
            'Account creation/verification/recovery, server-backed branch/staff actions, subscription payments, AI matching, digital invoice links and support messages need internet. Online reports, uploads and shared records may also need a server connection. A Wi-Fi connection alone does not guarantee the server is reachable.',
        answerBn:
            'অ্যাকাউন্ট খোলা/যাচাই/পুনরুদ্ধার, সার্ভারভিত্তিক শাখা–স্টাফের কাজ, সাবস্ক্রিপশন পেমেন্ট, AI, ডিজিটাল চালানের লিংক ও সাপোর্ট বার্তায় ইন্টারনেট লাগে। অনলাইন রিপোর্ট, আপলোড ও শেয়ার করা তথ্যে সার্ভার লাগতে পারে। শুধু Wi-Fi চালু থাকাই সার্ভারে পৌঁছানোর নিশ্চয়তা নয়।',
      ),
      HelpFaqEntry(
        id: 'sync-now',
        questionEn: 'When does data sync, and can I start it manually?',
        questionBn: 'তথ্য কখন সিঙ্ক হয়, নিজে থেকে সিঙ্ক দিতে পারব?',
        answerEn:
            'The app attempts sync when connectivity is available. You can also use Sync now in More or Settings → Internet & sync. Keep the app connected and check the result/pending status; being online is not the same as a completed successful sync.',
        answerBn:
            'সংযোগ পাওয়া গেলে অ্যাপ সিঙ্কের চেষ্টা করে। আরও বা সেটিংস → ইন্টারনেট ও সিঙ্ক থেকে এখনই সিঙ্ক দিতে পারেন। সংযুক্ত রেখে ফলাফল/অপেক্ষমাণ অবস্থা দেখুন; অনলাইনে থাকা মানেই সফল সিঙ্ক শেষ নয়।',
      ),
      HelpFaqEntry(
        id: 'sync-failed',
        questionEn: 'What should I do if the app shows offline or sync failed?',
        questionBn: 'অ্যাপ অফলাইন বা সিঙ্ক ব্যর্থ দেখালে কী করব?',
        answerEn:
            'Check internet and retry Sync now. The server, session or a record validation problem may need attention even when other apps work. Keep pending records on the phone and contact support with the error and time. Do not clear app storage, uninstall or recreate transactions to fix sync.',
        answerBn:
            'ইন্টারনেট দেখে এখনই সিঙ্ক দিয়ে চেষ্টা করুন। অন্য অ্যাপ চললেও সার্ভার, সেশন বা কোনো রেকর্ডের তথ্য যাচাইয়ে সমস্যা থাকতে পারে। অপেক্ষমাণ তথ্য ফোনে রেখে সময় ও ত্রুটিসহ সাপোর্টে জানান। সমাধান হিসেবে স্টোরেজ মুছবেন না, আনইনস্টল বা একই লেনদেন আবার তৈরি করবেন না।',
      ),
      HelpFaqEntry(
        id: 'multiple-devices',
        questionEn: 'Will another phone see my offline changes immediately?',
        questionBn: 'আমার অফলাইনের পরিবর্তন অন্য ফোনে সঙ্গে সঙ্গে দেখা যাবে?',
        answerEn:
            'No. Changes must first upload successfully, then the other device must connect and refresh/sync the same shop and branch. Avoid editing the same records offline on multiple phones, especially selling the last stock, because devices cannot see each other’s pending changes.',
        answerBn:
            'না। আগে পরিবর্তন সফলভাবে আপলোড হতে হবে; এরপর অন্য ফোনে একই দোকান ও শাখায় অনলাইনে হালনাগাদ/সিঙ্ক করতে হবে। একাধিক ফোনে অফলাইনে একই তথ্য বদলানো, বিশেষ করে শেষ স্টক বিক্রি করা এড়িয়ে চলুন; এক ফোন অন্যটির অপেক্ষমাণ পরিবর্তন জানে না।',
      ),
      HelpFaqEntry(
        id: 'backup',
        questionEn: 'How do I keep an independent backup?',
        questionBn: 'আলাদা ব্যাকআপ কীভাবে রাখব?',
        answerEn:
            'Use Settings → Data & backup → Export data for the available local records. Keep a protected copy outside this phone and verify it. This file is not a full server/image backup and may contain private business data; store original documents separately. Sync and receipts/PDFs are not substitutes for independent backups.',
        answerBn:
            'সেটিংস → তথ্য ও ব্যাকআপ → তথ্য এক্সপোর্ট থেকে ফোনে থাকা রেকর্ডের ফাইল নিন। ফোনের বাইরে নিরাপদ কপি রেখে যাচাই করুন। এটি পুরো সার্ভার/ছবির ব্যাকআপ নয় এবং এতে ব্যক্তিগত ব্যবসার তথ্য থাকতে পারে; মূল কাগজ আলাদা রাখুন। সিঙ্ক বা রসিদ/PDF আলাদা ব্যাকআপের বিকল্প নয়।',
      ),
      HelpFaqEntry(
        id: 'restore',
        questionEn: 'How do I restore a backup safely?',
        questionBn: 'নিরাপদে ব্যাকআপ ফিরিয়ে আনব কীভাবে?',
        answerEn:
            'Choose Restore backup under Data & backup while signed into the intended shop. Select a compatible Mohajon backup and read the confirmation before continuing. Export the current data first and do not use another shop’s file. Ask support if you are unsure what will be restored.',
        answerBn:
            'সঠিক দোকানে লগইন করে তথ্য ও ব্যাকআপ থেকে ব্যাকআপ পুনরুদ্ধার বেছে সামঞ্জস্যপূর্ণ মহাজন ব্যাকআপ দিন। নিশ্চিতকরণের বার্তা পড়ুন। আগে বর্তমান তথ্যের এক্সপোর্ট রাখুন এবং অন্য দোকানের ফাইল দেবেন না। কী ফিরবে নিশ্চিত না হলে সাপোর্টে জিজ্ঞেস করুন।',
      ),
      HelpFaqEntry(
        id: 'new-phone',
        questionEn: 'What should I do before reinstalling or changing phones?',
        questionBn: 'অ্যাপ আবার ইনস্টল বা ফোন বদলানোর আগে কী করব?',
        answerEn:
            'Finish sync and keep an independent backup first. Unsynced records and local-only images can be lost when storage is cleared, the app is removed or the phone is lost. Sign into the same account/shop on the new device and verify data before removing the old copy.',
        answerBn:
            'আগে সিঙ্ক শেষ করে আলাদা ব্যাকআপ রাখুন। স্টোরেজ মোছা, আনইনস্টল বা ফোন হারালে সিঙ্ক না হওয়া তথ্য ও শুধু ফোনে থাকা ছবি হারাতে পারেন। নতুন ফোনে একই অ্যাকাউন্ট/দোকানে লগইন করে তথ্য দেখে তবেই পুরোনো কপি সরান।',
      ),
    ],
  ),
  HelpFaqTopic(
    id: 'security',
    titleEn: 'Security, notifications & support',
    titleBn: 'নিরাপত্তা, বিজ্ঞপ্তি ও সাপোর্ট',
    entries: [
      HelpFaqEntry(
        id: 'app-lock',
        questionEn: 'How do I protect the app with a PIN or biometrics?',
        questionBn: 'PIN বা বায়োমেট্রিক দিয়ে অ্যাপ নিরাপদ রাখব কীভাবে?',
        answerEn:
            'Open Settings → Security and configure the app-lock options supported by your device. Keep the device screen lock enabled too. An app-lock PIN is separate from your account password and from a mobile-payment PIN.',
        answerBn:
            'সেটিংস → নিরাপত্তায় ডিভাইসে সমর্থিত অ্যাপ লক চালু করুন। ফোনের স্ক্রিন লকও রাখুন। অ্যাপ লকের PIN, অ্যাকাউন্টের পাসওয়ার্ড ও মোবাইল পেমেন্টের PIN আলাদা বিষয়।',
      ),
      HelpFaqEntry(
        id: 'session-expired',
        questionEn: 'Why does the app sometimes ask me to sign in again?',
        questionBn: 'অ্যাপ কখনো আবার লগইন করতে বলে কেন?',
        answerEn:
            'The app normally renews a valid session when online. Revoked/invalid credentials, password recovery or account restrictions can require sign-in again. An offline network failure should not be treated as proof that your account is deleted. Preserve pending data and contact support if repeated sign-outs occur.',
        answerBn:
            'অনলাইনে বৈধ সেশন সাধারণত নবায়ন হয়। সেশন বাতিল/অবৈধ হওয়া, পাসওয়ার্ড পুনরুদ্ধার বা অ্যাকাউন্টের সীমাবদ্ধতায় আবার লগইন লাগতে পারে। অফলাইনের সংযোগ ব্যর্থ মানেই অ্যাকাউন্ট মুছে গেছে নয়। অপেক্ষমাণ তথ্য রেখে বারবার লগআউট হলে সাপোর্টে জানান।',
      ),
      HelpFaqEntry(
        id: 'device-access',
        questionEn: 'What should I do if my phone is lost or staff leave?',
        questionBn: 'ফোন হারালে বা স্টাফ চলে গেলে কী করব?',
        answerEn:
            'Use the account/security device-session controls where available and change compromised credentials. The owner should remove/deactivate the staff member’s access. Ask support for help if you cannot secure the account; never share the owner login with replacement staff.',
        answerBn:
            'অ্যাকাউন্ট/নিরাপত্তায় ডিভাইসের সেশন নিয়ন্ত্রণের অপশন ব্যবহার করুন এবং ফাঁস হওয়া লগইনের তথ্য বদলান। মালিক সংশ্লিষ্ট স্টাফের অনুমতি সরিয়ে/নিষ্ক্রিয় করবেন। অ্যাকাউন্ট নিরাপদ করতে না পারলে সাপোর্টে জানান; নতুন স্টাফকে মালিকের লগইন দেবেন না।',
      ),
      HelpFaqEntry(
        id: 'notifications',
        questionEn: 'Where do I manage notifications and unread messages?',
        questionBn: 'বিজ্ঞপ্তি ও না-পড়া বার্তা কোথায় নিয়ন্ত্রণ করব?',
        answerEn:
            'Use the bell/inbox to review notifications and Settings → Notifications to manage available alerts. Phone-level notification permission and network conditions affect push delivery. A local notification preference does not itself change customer dues or business records.',
        answerBn:
            'বেল/ইনবক্সে বিজ্ঞপ্তি দেখুন এবং সেটিংস → বিজ্ঞপ্তিতে থাকা অপশন নিয়ন্ত্রণ করুন। ফোনের অনুমতি ও নেটওয়ার্কে পুশ বার্তা পৌঁছানো প্রভাবিত হয়। বিজ্ঞপ্তির পছন্দ বদলালে গ্রাহকের বাকি বা ব্যবসার তথ্য নিজে থেকে বদলায় না।',
      ),
      HelpFaqEntry(
        id: 'login-announcement',
        questionEn: 'Why does an announcement appear again after login?',
        questionBn: 'লগইনের পর একই ঘোষণা আবার দেখায় কেন?',
        answerEn:
            'An active admin announcement may appear after each successful login until its configured expiry time. Dismiss closes it for that login, not necessarily for future logins. Once it expires, it should no longer appear as an active login dialog.',
        answerBn:
            'অ্যাডমিনের সক্রিয় ঘোষণা নির্ধারিত মেয়াদ পর্যন্ত প্রতিটি সফল লগইনের পর দেখাতে পারে। বন্ধ করলে সেইবারের ডায়ালগ বন্ধ হয়; পরের লগইনের জন্য স্থায়ীভাবে নয়। মেয়াদ শেষ হলে সক্রিয় লগইন ডায়ালগ হিসেবে আর দেখানোর কথা নয়।',
      ),
      HelpFaqEntry(
        id: 'force-update',
        questionEn: 'Why must I update after signing in?',
        questionBn: 'লগইনের পর বাধ্যতামূলক আপডেট চাইছে কেন?',
        answerEn:
            'A minimum supported version may be required for compatibility or important fixes. Use Update to follow the Google Play flow when available. Store installation, account, network and your approval affect the update; returning without installing does not remove the requirement.',
        answerBn:
            'সামঞ্জস্য বা গুরুত্বপূর্ণ সংশোধনের জন্য ন্যূনতম সংস্করণ বাধ্যতামূলক হতে পারে। আপডেট চাপ দিয়ে প্রযোজ্য Google Play-এর ধাপ অনুসরণ করুন। স্টোরে ইনস্টল থাকা, অ্যাকাউন্ট, ইন্টারনেট ও আপনার অনুমোদনে আপডেট নির্ভর করে; ইনস্টল না করে ফিরলে বাধ্যবাধকতা সরে না।',
      ),
      HelpFaqEntry(
        id: 'delete-data',
        questionEn: 'How do I request or perform permanent data deletion?',
        questionBn: 'স্থায়ীভাবে তথ্য মুছব বা মুছে দেওয়ার অনুরোধ করব কীভাবে?',
        answerEn:
            'Review the privacy/data-management actions available for your account or contact support. Export anything you must keep and read the confirmation carefully. Permanent deletion can remove shop history and cannot be assumed reversible; it is different from signing out or uninstalling.',
        answerBn:
            'অ্যাকাউন্টে থাকা গোপনীয়তা/তথ্য ব্যবস্থাপনার অপশন দেখুন বা সাপোর্টে যোগাযোগ করুন। দরকারি তথ্য আগে এক্সপোর্ট করে নিশ্চিতকরণের বার্তা পড়ুন। স্থায়ী মোছায় দোকানের ইতিহাস সরতে পারে ও ফিরবে ধরে নেওয়া যাবে না; লগআউট বা আনইনস্টল থেকে এটি আলাদা।',
      ),
      HelpFaqEntry(
        id: 'contact-support',
        questionEn: 'How do I report a problem or contact support?',
        questionBn: 'সমস্যা জানাব বা সাপোর্টে যোগাযোগ করব কীভাবে?',
        answerEn:
            'Open Help & support → Message support while online. Describe the steps, expected result, app version and approximate time; attach a screenshot if helpful. Hide customer-sensitive information and never send passwords, OTPs, payment PINs, API keys or an unprotected full backup.',
        answerBn:
            'অনলাইনে সাহায্য ও সহায়তা → সাপোর্টে বার্তা পাঠান খুলুন। কীভাবে সমস্যা হলো, কী ফল চেয়েছিলেন, অ্যাপের সংস্করণ ও আনুমানিক সময় লিখুন; প্রয়োজনে ছবি দিন। গ্রাহকের সংবেদনশীল তথ্য ঢেকে দিন এবং পাসওয়ার্ড, OTP, পেমেন্ট PIN, API key বা অরক্ষিত পুরো ব্যাকআপ দেবেন না।',
      ),
    ],
  ),
];
