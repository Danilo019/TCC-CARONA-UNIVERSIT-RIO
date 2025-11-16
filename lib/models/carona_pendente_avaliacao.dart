/// Modelo para representar uma carona pendente de avaliação
class CaronaPendenteAvaliacao {
  final String caronaId;
  final String avaliadoUsuarioId;
  final String avaliadoNome;
  final String? avaliadoPhotoURL;
  final String tipo; // 'motorista' ou 'passageiro'
  final DateTime dataCarona;
  final String origem;
  final String destino;

  CaronaPendenteAvaliacao({
    required this.caronaId,
    required this.avaliadoUsuarioId,
    required this.avaliadoNome,
    this.avaliadoPhotoURL,
    required this.tipo,
    required this.dataCarona,
    required this.origem,
    required this.destino,
  });

  @override
  String toString() {
    return 'CaronaPendenteAvaliacao(caronaId: $caronaId, avaliadoNome: $avaliadoNome, tipo: $tipo)';
  }
}

