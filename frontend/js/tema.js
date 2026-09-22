// Alternância de tema claro/escuro. Escuro é o padrão; a preferência é
// lembrada em localStorage (por navegador, não sincroniza entre
// dispositivos — só uma conveniência).
const Tema = (() => {
  const CHAVE = "painel-eleicoes:tema";

  function lido() {
    try {
      return localStorage.getItem(CHAVE);
    } catch (e) {
      return null;
    }
  }

  function salvar(tema) {
    try {
      localStorage.setItem(CHAVE, tema);
    } catch (e) {
      // localStorage indisponível (aba privada, storage bloqueado) — sem problema, só não lembra.
    }
  }

  function aplicar(tema) {
    document.body.dataset.tema = tema;
    document.getElementById("btn-tema").textContent = tema === "escuro" ? "Escuro" : "Claro";
    Mapa.definirTema(tema);
    salvar(tema);
  }

  function iniciar() {
    const preferido = lido() || "escuro";
    aplicar(preferido);

    document.getElementById("btn-tema").addEventListener("click", () => {
      const atual = document.body.dataset.tema;
      aplicar(atual === "escuro" ? "claro" : "escuro");
    });
  }

  return { iniciar };
})();
