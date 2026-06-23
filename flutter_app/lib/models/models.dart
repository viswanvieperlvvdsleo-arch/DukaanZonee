import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum Role { user, seller, admin }

enum MapMode { standard, routing }

class MapState {
  final MapMode mode;
  final LatLng? destination;
  final String? destinationName;
  MapState({
    this.mode = MapMode.standard,
    this.destination,
    this.destinationName,
  });
}

class Product {
  const Product(
    this.id,
    this.name,
    this.price,
    this.shop,
    this.badge,
    this.stock,
    this.icon,
    this.tint, {
    this.imageUrl,
    this.shopId,
    this.shopBlock,
    this.shopCategory,
    this.shopAddress,
    this.paymentQrPayload,
    this.upiId,
    this.description,
    this.shopAvatarUrl,
    this.shopMapUrl,
    this.shopFollowerCount = 0,
    this.shopRating = 0,
    this.isFollowingShop = false,
    this.isSaved = false,
    this.promotionId,
  });
  final String id;
  final String name;
  final String price;
  final String shop;
  final String badge;
  final String stock;
  final IconData icon;
  final Color tint;
  final String? imageUrl;
  final String? shopId;
  final String? shopBlock;
  final String? shopCategory;
  final String? shopAddress;
  final String? paymentQrPayload;
  final String? upiId;
  final String? description;
  final String? shopAvatarUrl;
  final String? shopMapUrl;
  final int shopFollowerCount;
  final double shopRating;
  final bool isFollowingShop;
  final bool isSaved;
  final String? promotionId;
}

class Shop {
  const Shop(
    this.name,
    this.block,
    this.type,
    this.rating,
    this.orders,
    this.location, {
    this.id,
    this.address,
    this.paymentQrPayload,
    this.upiId,
    this.gatewayProvider,
    this.phone,
    this.avatarUrl,
    this.mapUrl,
    this.followerCount = 0,
    this.ratingValue = 0,
    this.isFollowing = false,
    this.sellerId,
  });
  final String name;
  final String block;
  final String type;
  final String rating;
  final String orders;
  final LatLng location;
  final String? id;
  final String? address;
  final String? paymentQrPayload;
  final String? upiId;
  final String? gatewayProvider;
  final String? phone;
  final String? avatarUrl;
  final String? mapUrl;
  final int followerCount;
  final double ratingValue;
  final bool isFollowing;
  final String? sellerId;
}

class Stat {
  const Stat(this.label, this.value, this.trend, this.icon, this.bg);
  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final Color bg;
}
