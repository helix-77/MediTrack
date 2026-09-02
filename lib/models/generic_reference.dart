class GenericReference {
  final int id;
  final String genericName;
  final String? slug;
  final String? drugClass;
  final String? indication;
  final String? monographLink;
  final String? indicationDesc;
  final String? therapeuticClassDesc;
  final String? pharmacologyDesc;
  final String? dosageDesc;
  final String? administrationDesc;
  final String? interactionDesc;
  final String? contraindicationsDesc;
  final String? sideEffectsDesc;
  final String? pregnancyDesc;
  final String? precautionsDesc;
  final String? pediatricDesc;
  final String? overdoseDesc;
  final String? durationDesc;
  final String? reconstitutionDesc;
  final String? storageDesc;

  const GenericReference({
    required this.id,
    required this.genericName,
    this.slug,
    this.drugClass,
    this.indication,
    this.monographLink,
    this.indicationDesc,
    this.therapeuticClassDesc,
    this.pharmacologyDesc,
    this.dosageDesc,
    this.administrationDesc,
    this.interactionDesc,
    this.contraindicationsDesc,
    this.sideEffectsDesc,
    this.pregnancyDesc,
    this.precautionsDesc,
    this.pediatricDesc,
    this.overdoseDesc,
    this.durationDesc,
    this.reconstitutionDesc,
    this.storageDesc,
  });

  factory GenericReference.fromSqlite(Map<String, dynamic> map) {
    return GenericReference(
      id: (map['id'] as num?)?.toInt() ?? 0,
      genericName: map['generic_name'] as String? ?? '',
      slug: map['slug'] as String?,
      drugClass: map['drug_class'] as String?,
      indication: map['indication'] as String?,
      monographLink: map['monograph_link'] as String?,
      indicationDesc: map['indication_desc'] as String?,
      therapeuticClassDesc: map['therapeutic_class_desc'] as String?,
      pharmacologyDesc: map['pharmacology_desc'] as String?,
      dosageDesc: map['dosage_desc'] as String?,
      administrationDesc: map['administration_desc'] as String?,
      interactionDesc: map['interaction_desc'] as String?,
      contraindicationsDesc: map['contraindications_desc'] as String?,
      sideEffectsDesc: map['side_effects_desc'] as String?,
      pregnancyDesc: map['pregnancy_desc'] as String?,
      precautionsDesc: map['precautions_desc'] as String?,
      pediatricDesc: map['pediatric_desc'] as String?,
      overdoseDesc: map['overdose_desc'] as String?,
      durationDesc: map['duration_desc'] as String?,
      reconstitutionDesc: map['reconstitution_desc'] as String?,
      storageDesc: map['storage_desc'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'genericName': genericName,
      'slug': slug,
      'drugClass': drugClass,
      'indication': indication,
      'monographLink': monographLink,
      'indicationDesc': indicationDesc,
      'therapeuticClassDesc': therapeuticClassDesc,
      'pharmacologyDesc': pharmacologyDesc,
      'dosageDesc': dosageDesc,
      'administrationDesc': administrationDesc,
      'interactionDesc': interactionDesc,
      'contraindicationsDesc': contraindicationsDesc,
      'sideEffectsDesc': sideEffectsDesc,
      'pregnancyDesc': pregnancyDesc,
      'precautionsDesc': precautionsDesc,
      'pediatricDesc': pediatricDesc,
      'overdoseDesc': overdoseDesc,
      'durationDesc': durationDesc,
      'reconstitutionDesc': reconstitutionDesc,
      'storageDesc': storageDesc,
    };
  }
}
