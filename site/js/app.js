// Dados de demonstracao do painel Gota Inteligente.
// Na solucao completa estes valores vem do ESP32 (umidade) e da API de previsao do tempo.
var talhoes = [
  { nome: "Talhão 1 · Alface",   umid: 34, chuva: 10, temp: 27 },
  { nome: "Talhão 2 · Tomate",   umid: 58, chuva: 75, temp: 25 },
  { nome: "Talhão 3 · Mandioca", umid: 71, chuva: 20, temp: 29 }
];

function recomendar(t) {
  if (t.umid >= 65) return { cls: "ok", txt: "Solo úmido. Não precisa irrigar." };
  if (t.chuva >= 60) return { cls: "aguardar", txt: "Chuva prevista (" + t.chuva + "%). Aguarde." };
  if (t.umid < 40) return { cls: "irrigar", txt: "Irrigar agora: cerca de 20 min." };
  return { cls: "irrigar", txt: "Irrigar no fim da tarde: cerca de 10 min." };
}

function variar(v, passo, min, max) {
  v += (Math.random() * 2 - 1) * passo;
  return Math.max(min, Math.min(max, Math.round(v)));
}

function render() {
  var box = document.getElementById("talhoes");
  box.innerHTML = "";
  talhoes.forEach(function (t) {
    var r = recomendar(t);
    var el = document.createElement("article");
    el.className = "card talhao";
    el.innerHTML =
      "<h3>" + t.nome + "</h3>" +
      '<div class="linha"><span>Umidade do solo</span><b>' + t.umid + "%</b></div>" +
      '<div class="linha"><span>Chuva nas próximas 24 h</span><b>' + t.chuva + "%</b></div>" +
      '<div class="linha"><span>Temperatura</span><b>' + t.temp + " °C</b></div>" +
      '<div class="status ' + r.cls + '">' + r.txt + "</div>";
    box.appendChild(el);
  });

  var t1 = talhoes[0];
  document.getElementById("heroUmid").textContent = t1.umid + "%";
  document.getElementById("heroBarra").style.width = t1.umid + "%";
  document.getElementById("heroReco").textContent = recomendar(t1).txt;
  document.getElementById("relogio").textContent = new Date().toLocaleTimeString("pt-BR");
}

function tick() {
  talhoes.forEach(function (t) {
    t.umid = variar(t.umid, 2, 15, 90);
    t.chuva = variar(t.chuva, 4, 0, 100);
    t.temp = variar(t.temp, 1, 16, 36);
  });
  render();
}

document.getElementById("host").textContent = window.location.host || "arquivo local";
render();
setInterval(tick, 5000);
