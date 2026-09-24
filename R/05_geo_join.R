# Geometria (via geobr) e o de-para município -> microrregião/mesorregião.
#
# geobr::read_municipality() não traz código de meso/microrregião por
# município — só read_meso_region()/read_micro_region(), que dão os
# polígonos agregados sem o de-para. Em vez de depender de mais uma fonte
# externa, o de-para é derivado por join espacial: centroide do município
# contra os polígonos de meso/microrregião. Mesorregião e microrregião
# nunca cruzam fronteira de UF, então a correspondência é 1:1, sem
# ambiguidade.

obter_municipios_sf <- function(uf = "all", ano = 2020) {
  geobr::read_municipality(code_muni = uf, year = ano)
}

obter_meso_sf <- function(uf = "all", ano = 2020) {
  geobr::read_meso_region(code_meso = uf, year = ano)
}

obter_micro_sf <- function(uf = "all", ano = 2020) {
  geobr::read_micro_region(code_micro = uf, year = ano)
}

obter_uf_sf <- function(uf = "all", ano = 2020) {
  geobr::read_state(code_state = uf, year = ano)
}

#' Deriva o de-para município -> meso/microrregião por join espacial
#' (centroide do município dentro do polígono de meso/microrregião).
#'
#' @param municipios_sf sf de `obter_municipios_sf()`.
#' @param meso_sf sf de `obter_meso_sf()`.
#' @param micro_sf sf de `obter_micro_sf()`.
derivar_crosswalk_meso_micro <- function(municipios_sf, meso_sf, micro_sf) {
  centroides <- sf::st_centroid(sf::st_geometry(municipios_sf))

  idx_meso <- sf::st_within(centroides, sf::st_geometry(meso_sf))
  idx_micro <- sf::st_within(centroides, sf::st_geometry(micro_sf))

  primeiro_ou_na <- function(idx) vapply(idx, function(x) if (length(x) > 0) x[[1]] else NA_integer_, integer(1))

  tibble::tibble(
    code_muni = municipios_sf$code_muni,
    code_meso = meso_sf$code_meso[primeiro_ou_na(idx_meso)],
    name_meso = meso_sf$name_meso[primeiro_ou_na(idx_meso)],
    code_micro = micro_sf$code_micro[primeiro_ou_na(idx_micro)],
    name_micro = micro_sf$name_micro[primeiro_ou_na(idx_micro)]
  )
}
