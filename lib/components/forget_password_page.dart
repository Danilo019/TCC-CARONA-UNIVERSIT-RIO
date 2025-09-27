import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:app_carona_novo/components/common/custom_form_button.dart';
import 'package:app_carona_novo/components/common/page_header.dart';
import 'package:app_carona_novo/components/common/page_heading.dart';
import 'package:app_carona_novo/components/common/custom_input_field.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final _forgetPasswordFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xffEEF1F3),
        body: Column(
          children: [
            const PageHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _forgetPasswordFormKey,
                    child: Column(
                      children: [
                        const PageHeading(
                          title: 'Esqueceu sua senha',
                        ),
                        CustomInputField(
                            labelText: 'Email',
                            hintText: 'seu.email.academico@cs.udf.edu.br',
                            isDense: true,
                            validator: (textValue) {
                              if (textValue == null || textValue.isEmpty) {
                                return 'Email é obrigatório!';
                              }
                              if (!EmailValidator.validate(textValue)) {
                                return 'Por favor, insira um email válido';
                              }
                              return null;
                            }),
                        const SizedBox(
                          height: 20,
                        ),
                        CustomFormButton(
                          innerText: 'Enviar',
                          onPressed: _handleForgetPassword,
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Container(
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                                context, '/login'),
                            child: const Text(
                              'Voltar para login',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xff939393),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleForgetPassword() {
    // forget password
    if (_forgetPasswordFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enviando dados...')),
      );
    }
  }
}
