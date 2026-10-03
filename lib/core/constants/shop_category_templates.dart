/// Shop-specific product category presets used during onboarding and product entry.
///
/// These are suggestions, not restrictions: every shop can still use custom
/// categories and existing product categories are always preserved.
class ShopCategoryTemplate {
  const ShopCategoryTemplate({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.categories,
  });

  final String id;
  final String nameEn;
  final String nameBn;
  final List<String> categories;
}

class ShopCategoryTemplates {
  static const general = ShopCategoryTemplate(
    id: 'general',
    nameEn: 'General store',
    nameBn: 'জেনারেল স্টোর',
    categories: [
      'Grocery',
      'Beverages',
      'Personal Care',
      'Rice',
      'Dairy',
      'Meat',
      'Vegetables',
      'Health',
    ],
  );

  static const medicine = ShopCategoryTemplate(
    id: 'medicine',
    nameEn: 'Medicine / Pharmacy',
    nameBn: 'মেডিসিন / ফার্মেসি',
    categories: [
      'Tablet',
      'Capsule',
      'Syrup',
      'Injection',
      'Medical Equipment',
      'Vitamins & Supplements',
      'Personal Care',
      'Baby Care',
    ],
  );

  static const grocery = ShopCategoryTemplate(
    id: 'grocery',
    nameEn: 'Grocery / Super shop',
    nameBn: 'মুদি / সুপার শপ',
    categories: [
      'Rice & Grains',
      'Dal & Pulses',
      'Oil & Ghee',
      'Spices',
      'Snacks',
      'Beverages',
      'Dairy',
      'Household',
    ],
  );

  static const clothing = ShopCategoryTemplate(
    id: 'clothing',
    nameEn: 'Clothing / Fashion',
    nameBn: 'কাপড় / ফ্যাশন',
    categories: [
      'Men',
      'Women',
      'Kids',
      'Saree',
      'Panjabi',
      'Shoes',
      'Bags',
      'Accessories',
    ],
  );

  static const electronics = ShopCategoryTemplate(
    id: 'electronics',
    nameEn: 'Electronics',
    nameBn: 'ইলেকট্রনিক্স',
    categories: [
      'Mobile',
      'Computer',
      'Charger & Cable',
      'Earphone & Audio',
      'Television',
      'Home Appliance',
      'Accessories',
      'Repair Service',
    ],
  );

  static const cosmetics = ShopCategoryTemplate(
    id: 'cosmetics',
    nameEn: 'Cosmetics / Beauty',
    nameBn: 'কসমেটিক্স / বিউটি',
    categories: [
      'Skincare',
      'Haircare',
      'Makeup',
      'Fragrance',
      'Personal Care',
      'Nail Care',
      'Men\'s Grooming',
      'Beauty Tools',
    ],
  );

  static const restaurant = ShopCategoryTemplate(
    id: 'restaurant',
    nameEn: 'Restaurant / Food',
    nameBn: 'রেস্টুরেন্ট / খাবার',
    categories: [
      'Main Course',
      'Rice & Biryani',
      'Snacks',
      'Beverages',
      'Dessert',
      'Fast Food',
      'Raw Materials',
      'Combo',
    ],
  );

  static const all = <ShopCategoryTemplate>[
    general,
    medicine,
    grocery,
    clothing,
    electronics,
    cosmetics,
    restaurant,
  ];

  static ShopCategoryTemplate forId(String? id) => all.firstWhere(
        (template) => template.id == id,
        orElse: () => general,
      );
}
