/// Local rules only, not a clinical detector. No storage, logging or networking.
class RiskSupportService {
  bool shouldOffer(String input) {
    final text = input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
    final sentences = text.split(RegExp(r'[.!?;\n]'));
    final direct = RegExp(
      r'\b(quiero (morir|matarme|suicidarme|hacerme dano)|voy a (matarme|suicidarme|hacerme dano)|me quiero (matar|suicidar)|no quiero seguir viviendo|pienso (suicidarme|matarme))\b',
    );
    final negation = RegExp(
      r'\b(no|nunca|jamas)\s+(ya\s+)?(quiero (morir|matarme|suicidarme|hacerme dano)|voy a (matarme|suicidarme|hacerme dano)|me quiero (matar|suicidar)|pienso (suicidarme|matarme))\b',
    );
    return sentences.any((s) => direct.hasMatch(s) && !negation.hasMatch(s));
  }
}
