enum UserRole { owner, cashier }
UserRole userRoleFromString(String s) => s == 'owner' ? UserRole.owner : UserRole.cashier;
String userRoleToString(UserRole r) => r == UserRole.owner ? 'owner' : 'cashier';
