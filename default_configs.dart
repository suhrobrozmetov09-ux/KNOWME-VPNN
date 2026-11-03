// O'zingizning .conf matnlaringizni shu yerga qo'ying.
// Kalit: serverning ko'rinadigan nomi, qiymat: .conf faylining to'liq matni.
// Bo'sh qoldirsangiz, foydalanuvchi ilovada o'zi .conf import qiladi.
//
// Misol:
// const Map<String, String> defaultConfigs = {
//   'Server 1': '''
// [Interface]
// PrivateKey = ...
// Address = 10.0.0.2/32
// DNS = 1.1.1.1
//
// [Peer]
// PublicKey = ...
// Endpoint = 1.2.3.4:51820
// AllowedIPs = 0.0.0.0/0, ::/0
// PersistentKeepalive = 25
// ''',
// };

const Map<String, String> defaultConfigs = {};
