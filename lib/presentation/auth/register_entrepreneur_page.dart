import 'package:flutter/material.dart';

import 'registration_page.dart';

class RegisterEntrepreneurPage extends StatelessWidget {
  const RegisterEntrepreneurPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AccountRegistrationPage(role: 'entrepreneur');
}
