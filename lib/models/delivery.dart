class Delivery {
  final int? id;
  final String codigo;
  final String nomeDestinatario;
  final String endereco;
  final String status;
  final double latitude;
  final double longitude;
  final String dataHoraAtualizacao;

  Delivery({
    this.id,
    required this.codigo,
    required this.nomeDestinatario,
    required this.endereco,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.dataHoraAtualizacao,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'codigo': codigo,
        'nomeDestinatario': nomeDestinatario,
        'endereco': endereco,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'dataHoraAtualizacao': dataHoraAtualizacao,
      };

  factory Delivery.fromMap(Map<String, dynamic> map) => Delivery(
        id: map['id'],
        codigo: map['codigo'],
        nomeDestinatario: map['nomeDestinatario'],
        endereco: map['endereco'],
        status: map['status'],
        latitude: map['latitude'],
        longitude: map['longitude'],
        dataHoraAtualizacao: map['dataHoraAtualizacao'],
      );

  Delivery copyWith({
    int? id,
    String? codigo,
    String? nomeDestinatario,
    String? endereco,
    String? status,
    double? latitude,
    double? longitude,
    String? dataHoraAtualizacao,
  }) =>
      Delivery(
        id: id ?? this.id,
        codigo: codigo ?? this.codigo,
        nomeDestinatario: nomeDestinatario ?? this.nomeDestinatario,
        endereco: endereco ?? this.endereco,
        status: status ?? this.status,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        dataHoraAtualizacao: dataHoraAtualizacao ?? this.dataHoraAtualizacao,
      );
}
