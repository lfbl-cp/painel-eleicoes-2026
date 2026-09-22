// Camada de dados: carrega output/index.json uma vez e busca/cacheia
// topojson + resultado sob demanda. "BASE" assume que este arquivo é
// servido a partir de frontend/, com output/ como pasta irmã (na raiz do
// projeto) — ajustar se a hospedagem final mudar essa estrutura.
const BASE = "..";

const Dados = (() => {
  let indice = null;
  const cacheGeo = new Map();
  const cacheResultado = new Map();

  async function carregarIndice() {
    if (indice) return indice;
    const resp = await fetch(`${BASE}/output/index.json`);
    if (!resp.ok) throw new Error(`Falha ao carregar index.json: ${resp.status}`);
    indice = await resp.json();
    return indice;
  }

  function entradas() {
    if (!indice) throw new Error("Chame carregarIndice() antes de entradas().");
    return indice.entradas;
  }

  async function carregarGeo(caminho) {
    if (cacheGeo.has(caminho)) return cacheGeo.get(caminho);
    const resp = await fetch(`${BASE}/${caminho}`);
    if (!resp.ok) throw new Error(`Falha ao carregar geometria ${caminho}: ${resp.status}`);
    const topo = await resp.json();
    cacheGeo.set(caminho, topo);
    return topo;
  }

  async function carregarResultado(caminho) {
    if (cacheResultado.has(caminho)) return cacheResultado.get(caminho);
    const resp = await fetch(`${BASE}/${caminho}`);
    if (!resp.ok) throw new Error(`Falha ao carregar resultado ${caminho}: ${resp.status}`);
    const json = await resp.json();
    cacheResultado.set(caminho, json);
    return json;
  }

  return { carregarIndice, entradas, carregarGeo, carregarResultado };
})();
