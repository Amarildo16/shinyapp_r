# Cache i përbashkët i modeleve (P-07): Modelimi dhe Parashikimi marrin të njëjtin
# ETS/ARIMA për të njëjtën seri, pa e rillogaritur. Çelësi: lloji + vlerat + tsp() e serisë.
# Modelet janë deterministe, ndaj ruhet edhe dështimi (NULL), që të mos riprovohet.

model_store <- function(fitters = list(ets = fit_ets, arima = fit_arima),
                        cache = cachem::cache_mem(max_size = 128 * 1024^2)) {
  key_of <- function(type, y) {
    rlang::hash(list(type, as.numeric(y), stats::tsp(y)))
  }

  has <- function(type, y) cache$exists(key_of(type, y))

  get <- function(type, y) {
    key <- key_of(type, y)
    if (cache$exists(key)) return(cache$get(key))
    fit <- fitters[[type]](y)
    cache$set(key, fit)
    fit
  }

  list(has = has, get = get)
}
