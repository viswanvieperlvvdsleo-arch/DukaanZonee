export const paymentProviderIds = ['mock_gateway', 'razorpay', 'phonepe'];

const gatewayDefinitions = {
  mock_gateway: {
    id: 'mock_gateway',
    label: 'Mock Gateway',
    referencePrefix: 'MOCK',
    feeRate: Number(process.env.MOCK_GATEWAY_FEE_RATE ?? 0.0236),
    envKeys: [],
    note: 'Local sandbox checkout. No real money moves.',
  },
  razorpay: {
    id: 'razorpay',
    label: 'Razorpay',
    referencePrefix: 'RZP',
    feeRate: Number(process.env.RAZORPAY_GATEWAY_FEE_RATE ?? 0.0236),
    envKeys: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET'],
    note: 'Adapter ready. Real capture waits for Razorpay keys and webhook.',
  },
  phonepe: {
    id: 'phonepe',
    label: 'PhonePe',
    referencePrefix: 'PHONEPE',
    feeRate: Number(process.env.PHONEPE_GATEWAY_FEE_RATE ?? 0.02),
    envKeys: ['PHONEPE_MERCHANT_ID', 'PHONEPE_SALT_KEY'],
    note: 'Adapter ready. Real capture waits for PhonePe merchant credentials and webhook.',
  },
};

export function getPaymentGateway(providerId = 'mock_gateway') {
  const id = paymentProviderIds.includes(providerId) ? providerId : 'mock_gateway';
  const gateway = gatewayDefinitions[id];
  const missingEnv = gateway.envKeys.filter((key) => !process.env[key]);
  return {
    ...gateway,
    mode: id === 'mock_gateway'
      ? 'sandbox'
      : missingEnv.length === 0
        ? 'live_keys_configured'
        : 'sandbox_adapter',
    missingEnv,
    isLiveReady: id !== 'mock_gateway' && missingEnv.length === 0,
  };
}

export function listPaymentGateways() {
  return paymentProviderIds.map((id) => toPublicGateway(getPaymentGateway(id)));
}

export function toPublicGateway(gateway) {
  return {
    id: gateway.id,
    label: gateway.label,
    mode: gateway.mode,
    feeRate: gateway.feeRate,
    isLiveReady: gateway.isLiveReady,
    missingEnv: gateway.missingEnv,
    note: gateway.note,
  };
}

export function estimateGatewayFeeCents(grossCents, providerId) {
  const gateway = getPaymentGateway(providerId);
  return Math.round(grossCents * gateway.feeRate);
}

export function makeGatewayReference(providerId, paymentId) {
  const gateway = getPaymentGateway(providerId);
  return `${gateway.referencePrefix}-${paymentId}`;
}
