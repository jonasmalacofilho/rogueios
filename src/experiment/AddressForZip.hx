package experiment;

import haxe.Http;
using StringTools;

class AddressForZip {
	static function main()
	{
		var cep = Sys.args().shift();
		if (cep == null) throw "Missing CEP";

		var userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/56.0.2924.87 Safari/537.36";

		var hello = new Http("http://www.buscacep.correios.com.br/sistemas/buscacep/buscaEndereco.cfm");
		hello.addHeader("User-Agent", userAgent);
		hello.onStatus =
			function (status)
			{
				trace('HELLO responded with $status');
				if (status != 200) throw status;

				var query = new Http("http://www.buscacep.correios.com.br/sistemas/buscacep/resultadoBuscaEndereco.cfm");
				var cookies = [];
				for (h in hello.rawResponseHeaders) {
					if (h.name.toLowerCase() != "set-cookie") continue;
					var cookie = ~/^[ ]*([^ =])+=([^ ;])+/;
					if (!cookie.match(h.value)) throw 'QUERY ERROR Weird set-cookie-string: $h.value';
					cookies.push(cookie.matched(0));
				}
				query.addHeader("Cookie", cookies.join("; "));
				query.addHeader("User-Agent", userAgent);
				query.onData = 
					function (rawData)
					{
						var data = rawData.replace("\r", "");
						if (data.indexOf("CEP NAO ENCONTRADO") > 0) {
							trace('USER ERROR: couldn\'t find CEP $cep');
							return;
						}

						var marker = data.indexOf("DADOS ENCONTRADOS COM SUCESSO.");
						if (marker < 0) throw "QUERY ERROR: couldn't find marker";
						sys.io.File.saveContent("debug.html", data);

						var begin = data.indexOf('<table class="tmptabela">', marker);
						var end = data.indexOf('</table>', begin);

						var table = data.substring(begin, end + "</table>".length);

						var xml = Xml.parse(table);
						function findTd(node:haxe.xml.Fast, ?ret)
						{
							if (ret == null) ret = [];
							if (node.name == "td")
								ret.push(node.innerData);
							for (e in node.elements)
								findTd(e, ret);
							return ret;
						}
						function unescape(html:String)
						{
							var esc = ~/&([a-z]+);/ig;
							return esc.map(html, function (esc) return
								switch esc.matched(1) {
								case "iacute": "í";
								case "ccedil": "ç";
								case "atilde": "ã";
								case "nbsp": "";  // FIXME unicode non-breaking space or keep ignoring it?
								case _: esc.matched(0);  // FIXME complete, check https://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references
								});
						}
						var fields = findTd(new haxe.xml.Fast(xml)).map(unescape);
						trace('Logradouro ou nome: ${fields[0]}');
						trace('Bairro ou distrito: ${fields[1]}');
						trace('Localidate e UF: ${fields[2]}');
					}
				query.onStatus =
					function (status)
					{
						trace('QUERY responded with $status');
						if (status != 200) throw status;
					}
				query.onError = function (msg) throw 'QUERY ERROR: $msg';
				query.addParameter("CEP", cep);
				query.request(true);
			}
		hello.onError = function (msg) throw 'HELLO ERROR: $msg';
		hello.request(false);
	}
}

