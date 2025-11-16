/// Modelo de dados para cada página do onboarding
/// 
/// Encapsula todas as informações necessárias para renderizar
/// uma tela individual do fluxo de onboarding.
class OnboardingPageModel {
  /// Título principal da página
  final String title;

  /// Descrição detalhada do recurso
  final String description;

  /// Caminho para o asset da ilustração (SVG ou PNG)
  final String imagePath;

  /// Cor de destaque opcional para esta página específica
  final String? accentColor;

  const OnboardingPageModel({
    required this.title,
    required this.description,
    required this.imagePath,
    this.accentColor,
  });
  @override
  String toString() {
    return 'OnboardingPageModel(title: $title, description: $description, imagePath: $imagePath, accentColor: $accentColor)';
  }
}

/// Lista de páginas do onboarding do aplicativo Carona Uni
class OnboardingData {
  OnboardingData._(); // Construtor privado

  static const List<OnboardingPageModel> pages = [
    OnboardingPageModel(
      title: 'Bem-vindo à Carona Universitária!',
      description:
          'Conecte-se com colegas da sua universidade e compartilhe caronas de forma segura, prática e econômica. Sua jornada acadêmica começa aqui!',
      imagePath: 'assets/images/background_android.png',
    ),
    OnboardingPageModel(
      title: 'Ofereça ou Encontre Caronas',
      description:
          'Publique sua rota diária ou encontre caronas disponíveis na sua região. Combine horários, locais de encontro e torne seu trajeto mais agradável.',
      imagePath: 'assets/images/message_illustration.png',
    ),
    OnboardingPageModel(
      title: 'Economize e Faça a Diferença',
      description:
          'Divida os custos da viagem, reduza o trânsito e contribua para um planeta mais sustentável. Juntos, fazemos a diferença!',
      imagePath: 'assets/images/logo_carona_universitária.png',
    ),
  ];

  /// Retorna o número total de páginas
  static int get pageCount => pages.length;

  /// Retorna uma página específica pelo índice
  static OnboardingPageModel getPage(int index) {
    if (index < 0 || index >= pages.length) {
      throw RangeError('Índice de página inválido: $index');
    }
    return pages[index];
  }
}

