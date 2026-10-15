source(testthat::test_path("..", "..", "R", "09_exportar.R"))
source(testthat::test_path("..", "..", "R", "10_swing.R"))

resultado_ficticio <- function(candidatos) {
  list(unidade = "municipio", cargo = "Presidente", turno = 1, vencedores = list(), candidatos = candidatos)
}

testthat::test_that("montar_swing_unidade compara Flávio 2026 com Jair 2022 e Lula com Lula", {
  base <- resultado_ficticio(list(
    "1" = list(nome = "Lula", partido = "PT", cor = "#C0272D", pct_geral = 48.43, valores = list(A = 60, B = 30)),
    "2" = list(nome = "Jair Bolsonaro", partido = "PL", cor = "#003882", pct_geral = 43.2, valores = list(A = 35, B = 65))
  ))
  atual <- resultado_ficticio(list(
    "9" = list(nome = "Lula", partido = "PT", cor = "#C0272D", pct_geral = 45.16, valores = list(A = 55.5, B = 31, C = 50)),
    "8" = list(nome = "Flavio Bolsonaro", partido = "PL", cor = "#003882", pct_geral = 47.03, valores = list(A = 40, B = 60, C = 50))
  ))

  swing <- montar_swing_unidade(atual, base, 2026, 2022)

  testthat::expect_equal(names(swing$candidatos), c("lula", "flavio"))
  testthat::expect_equal(swing$candidatos$lula$valores$A$swing, -4.5)
  testthat::expect_equal(swing$candidatos$lula$valores$B$swing, 1)
  testthat::expect_equal(swing$candidatos$flavio$valores$A$swing, 5)
  testthat::expect_equal(swing$candidatos$flavio$valores$B$base, 65)
  testthat::expect_equal(swing$candidatos$flavio$nome_base, "Jair Bolsonaro")
  testthat::expect_equal(swing$candidatos$flavio$rotulo, "Flávio Bolsonaro")
  testthat::expect_equal(swing$candidatos$flavio$swing_geral, 3.83)
  # Unidade só presente num dos anos fica de fora.
  testthat::expect_null(swing$candidatos$lula$valores$C)
  testthat::expect_equal(swing$escala_max, 5)
})

testthat::test_that("encontrar_candidato aborta quando o nome não existe", {
  r <- resultado_ficticio(list("1" = list(nome = "Lula", valores = list())))
  testthat::expect_error(encontrar_candidato(r, "Jair Bolsonaro"))
})

testthat::test_that("mesclar_index preserva outros anos e infere ano de entradas antigas", {
  caminho <- tempfile(fileext = ".json")
  antigo <- list(gerado_em = "x", entradas = list(
    list(uf = "BR", cargo = "Presidente", turno = 1, unidade = "uf",
         arquivo_resultado = "output/results/2022/BR_uf_presidente_t1.json", arquivo_geo = "g")
  ))
  jsonlite::write_json(antigo, caminho, auto_unbox = TRUE)

  novas <- list(list(ano = 2026L, uf = "BR", cargo = "Presidente", turno = 1L, unidade = "uf",
                     arquivo_resultado = "output/results/2026/BR_uf_presidente_t1.json", arquivo_geo = "g"))
  index <- mesclar_index(novas, caminho)

  testthat::expect_length(index$entradas, 2)
  testthat::expect_equal(sort(vapply(index$entradas, function(e) as.integer(e$ano), integer(1))), c(2022L, 2026L))

  # Reexecutar o mesmo ano substitui, não duplica.
  jsonlite::write_json(index, caminho, auto_unbox = TRUE)
  testthat::expect_length(mesclar_index(novas, caminho)$entradas, 2)
})
