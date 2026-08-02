import '../domain/product.dart';

final DateTime _now = DateTime.now();

final List<Product> sampleProducts = [
  Product(
    id: 'p_6840EA',
    name: 'Motorized Treadmill',
    brand: 'Premier',
    productCode: '6840EA',
    category: 'Cardio',
    sellingPrice: 8500.0,
    openingStock: 15,
    description:
        'Heavy-duty commercial treadmill designed for continuous gym use.',
    createdAt: _now,
    updatedAt: _now,
  ),
  Product(
    id: 'p_E33',
    name: 'Elipitical Cross Trainer',
    brand: 'Premier',
    productCode: 'E33',
    category: 'Cardio',
    sellingPrice: 4800.0,
    openingStock: 0,
    description:
        'Heavy-duty commercial Crosstrainer designed for continuous gym use',
    createdAt: _now,
    updatedAt: _now,
  ),
  Product(
    id: 'p_FH003',
    name: 'Shoulder Press',
    brand: 'Premier',
    productCode: 'FH003',
    category: 'Strength',
    sellingPrice: 4500.0,
    openingStock: 10,
    description:
        'Heavy-duty commercial Strength Machine for continuous gym use',
    createdAt: _now,
    updatedAt: _now,
  ),
  Product(
    id: 'p_TB65',
    name: 'Super Squat',
    brand: 'Premier',
    productCode: 'TB65',
    category: 'Strength',
    sellingPrice: 4250.0,
    openingStock: 5,
    description:
        'Heavy-duty commercial Strength Machine for continuous gym use',
    createdAt: _now,
    updatedAt: _now,
  ),
  Product(
    id: 'p_FX0013',
    name: 'Gym Rubber Mat Tile, White Fleck',
    brand: 'Floorex',
    productCode: 'FX0013',
    category: 'Flooring',
    sellingPrice: 110.0,
    openingStock: 500,
    description:
        'Heavy-duty commercial Strength Machine for continuous gym use',
    createdAt: _now,
    updatedAt: _now,
  ),
];
