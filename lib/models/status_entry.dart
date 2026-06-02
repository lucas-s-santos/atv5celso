class StatusEntry {
  final int? id;
  final int deliveryId;
  final String status;
  final String dataHora;

  StatusEntry({
    this.id,
    required this.deliveryId,
    required this.status,
    required this.dataHora,
  });

  factory StatusEntry.fromMap(Map<String, dynamic> map) => StatusEntry(
        id: map['id'],
        deliveryId: map['deliveryId'],
        status: map['status'],
        dataHora: map['dataHora'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'deliveryId': deliveryId,
        'status': status,
        'dataHora': dataHora,
      };
}
