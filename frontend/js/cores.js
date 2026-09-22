// Helpers de cor: interpolação (branco -> cor do candidato) para o modo
// contínuo, e paleta fixa pro LISA.
const Cores = (() => {
  const PALETA_LISA = {
    HH: "#d7191c",
    LL: "#2c7bb6",
    HL: "#fdae61",
    LH: "#abd9e9",
    "Não significante": "#e0e0e0",
  };

  function hexParaRgb(hex) {
    const limpo = hex.replace("#", "");
    return {
      r: parseInt(limpo.substring(0, 2), 16),
      g: parseInt(limpo.substring(2, 4), 16),
      b: parseInt(limpo.substring(4, 6), 16),
    };
  }

  function rgbParaHex({ r, g, b }) {
    const canal = (v) => Math.round(v).toString(16).padStart(2, "0");
    return `#${canal(r)}${canal(g)}${canal(b)}`;
  }

  // t em [0,1]: 0 = quase branco, 1 = cor cheia do candidato.
  function interpolarComBranco(corHex, t) {
    const alvo = hexParaRgb(corHex);
    const branco = { r: 245, g: 245, b: 245 };
    const tc = Math.max(0, Math.min(1, t));
    return rgbParaHex({
      r: branco.r + (alvo.r - branco.r) * tc,
      g: branco.g + (alvo.g - branco.g) * tc,
      b: branco.b + (alvo.b - branco.b) * tc,
    });
  }

  // t em [0,1]: 0 = cor cheia do candidato, 1 = quase preto. Usado pra
  // dar o tom mais escuro de "margem de vitória alta" no modo Vencedor.
  function escurecer(corHex, t) {
    const alvo = hexParaRgb(corHex);
    const preto = { r: 20, g: 20, b: 20 };
    const tc = Math.max(0, Math.min(1, t));
    return rgbParaHex({
      r: alvo.r + (preto.r - alvo.r) * tc,
      g: alvo.g + (preto.g - alvo.g) * tc,
      b: alvo.b + (preto.b - alvo.b) * tc,
    });
  }

  function corLisa(cluster) {
    return PALETA_LISA[cluster] || "#cccccc";
  }

  return { interpolarComBranco, escurecer, corLisa, PALETA_LISA };
})();
