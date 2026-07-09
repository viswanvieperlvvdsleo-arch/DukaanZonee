import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../dukaan.dart';

class RazorpayService {
  static final RazorpayService instance = RazorpayService._();
  RazorpayService._();

  Razorpay? _razorpay;
  Completer<Map<String, dynamic>>? _paymentCompleter;
  String? _pendingOrderId;

  void init() {
    if (_razorpay != null) return;
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  Future<CompletedPayment> startPayment({
    required String keyId,
    required String orderId,
    required String paymentId,
    required int amountCents,
    required String shopName,
    required String userEmail,
    required String userPhone,
    required Shop shop,
    required CompletedPayment Function(Map<String, dynamic>, {Shop? fallbackShop}) mapPayment,
  }) async {
    init();
    _paymentCompleter = Completer<Map<String, dynamic>>();
    _pendingOrderId = orderId;

    final options = {
      'key': keyId,
      'amount': amountCents,
      'name': shopName,
      'order_id': orderId,
      'description': 'Payment for shelf items',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      _paymentCompleter?.completeError('Razorpay failed to open: $e');
    }

    final result = await _paymentCompleter!.future;

    // Verify signature on backend
    final verifyData = await apiClient.postJson('/api/payment-sessions/razorpay/verify', {
      'paymentId': paymentId,
      'razorpayPaymentId': result['paymentId'],
      'razorpayOrderId': result['orderId'],
      'razorpaySignature': result['signature'],
    });

    final completedPayment = Map<String, dynamic>.from(verifyData['payment'] as Map);
    return mapPayment(completedPayment, fallbackShop: shop);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _paymentCompleter?.complete({
      'paymentId': response.paymentId,
      'orderId': response.orderId ?? _pendingOrderId,
      'signature': response.signature,
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _paymentCompleter?.completeError(
      response.message ?? 'Payment failed with code ${response.code}',
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _paymentCompleter?.completeError(
      'External wallet ${response.walletName} selected - not supported',
    );
  }
}

final razorpayService = RazorpayService.instance;
