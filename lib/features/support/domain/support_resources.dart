/// Mexico directory resource verified 2026-10-31. Regional config separate from rules.
class SupportResource {
  const SupportResource(
    this.country,
    this.name,
    this.phone,
    this.phoneLink,
    this.website,
  );
  final String country, name, phone, phoneLink, website;
}

const supportResources = [
  SupportResource(
    'México',
    'Línea de la Vida',
    '800 911 2000',
    'tel:+528009112000?oai_link_source=model_response_hotline',
    'https://www.gob.mx/conasama/articulos/linea-de-la-vida-800-911-2000?oai_link_source=model_response_hotline',
  ),
];
