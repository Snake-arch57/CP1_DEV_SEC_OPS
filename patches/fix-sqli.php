<?php
/**
 * Correção do SQL Injection — CWE-89
 *
 * Substitui `vulnerabilities/sqli/source/low.php`.
 *
 * Achado original (OpenGrep, regra
 * php.lang.security.injection.tainted-sql-string.tainted-sql-string,
 * 2 ocorrências, severidade `error`): a variável $id vem de $_REQUEST e é
 * concatenada diretamente na string da query. Qualquer conteúdo enviado pelo
 * usuário é interpretado como SQL.
 *
 * Código vulnerável (original do DVWA):
 *
 *     $id     = $_REQUEST[ 'id' ];
 *     $query  = "SELECT first_name, last_name FROM users WHERE user_id = '$id';";
 *     $result = mysqli_query($GLOBALS["___mysqli_ston"], $query);
 *
 * Confirmado na aplicação no ar, antes da correção: `id=1` devolve 1 linha,
 * e `id=1' OR '1'='1` devolve as 5 da tabela inteira.
 *
 * Correção: prepared statement com bind de parâmetro. O driver envia a query
 * e os dados em mensagens separadas, então o valor de $id nunca é analisado
 * como SQL — é sempre tratado como dado, qualquer que seja o conteúdo.
 *
 * Repare que não há sanitização, escape nem lista de caracteres proibidos.
 * Essa é a diferença conceitual: escapar tenta neutralizar a entrada, o
 * prepared statement remove a possibilidade de a entrada virar código.
 *
 * Depois da correção, na mesma aplicação no ar: `id=1` continua devolvendo a
 * linha do admin, e a injeção devolve 0 linhas — o banco procura um usuário
 * chamado `1' OR '1'='1` e não encontra.
 *
 * --- duas armadilhas que só aparecem rodando ---
 *
 * 1. A página monta a saída na variável $html e a imprime depois
 *    (`{$html}` no `index.php` da seção). Usar `echo` aqui joga o resultado
 *    no topo da página, fora do lugar.
 *
 * 2. A imagem do laboratório (`vulnerables/web-dvwa`) roda o **DVWA 1.9**,
 *    que não tem `$_DVWA['SQLI_DB']` nem as constantes `MYSQL` / `SQLITE`.
 *    Elas são do DVWA atual, que é o que o CI clona para o SAST. Usá-las sem
 *    checar quebra a página no laboratório: "Undefined index: SQLI_DB", e a
 *    consulta legítima passa a devolver zero linha. Por isso a detecção
 *    abaixo, em vez de um `switch` fixo — um patch só serve para os dois.
 */

if( isset( $_REQUEST[ 'Submit' ] ) ) {
	$id = $_REQUEST[ 'id' ];

	if( !isset( $html ) ) {
		$html = '';
	}

	// DVWA atual configurado em SQLite? No DVWA 1.9 nada disso existe, e a
	// expressão simplesmente dá falso.
	$usa_sqlite = isset( $_DVWA[ 'SQLI_DB' ] )
	              && defined( 'SQLITE' )
	              && $_DVWA[ 'SQLI_DB' ] == SQLITE;

	if( $usa_sqlite ) {
		global $sqlite_db_connection;

		// O placeholder :id entra na query; o valor, não.
		$stmt = $sqlite_db_connection->prepare(
			'SELECT first_name, last_name FROM users WHERE user_id = :id'
		);

		if( $stmt !== false ) {
			$stmt->bindValue( ':id', $id, SQLITE3_TEXT );
			$resultado = $stmt->execute();

			if( $resultado !== false ) {
				while( $linha = $resultado->fetchArray() ) {
					// htmlspecialchars evita que o dado vindo do banco vire
					// HTML na página: é defesa contra XSS (CWE-79), problema
					// distinto do SQL Injection mas no mesmo fluxo.
					$html .= "<pre>ID: " . htmlspecialchars( $id, ENT_QUOTES, 'UTF-8' ) .
					         "<br />First name: " . htmlspecialchars( $linha[ 'first_name' ], ENT_QUOTES, 'UTF-8' ) .
					         "<br />Surname: " . htmlspecialchars( $linha[ 'last_name' ], ENT_QUOTES, 'UTF-8' ) .
					         "</pre>";
				}
			}
		}
	}
	else {
		$mysqli = $GLOBALS[ "___mysqli_ston" ];

		// A query traz um placeholder, não o valor.
		$stmt = mysqli_prepare(
			$mysqli,
			"SELECT first_name, last_name FROM users WHERE user_id = ?"
		);

		if( $stmt !== false ) {
			// "s" = o parâmetro é string. O valor viaja fora da query.
			//
			// String, e não inteiro, de propósito: restringir $id a número
			// também resolveria este caso, mas resolveria por validação de
			// entrada. O que se quer demonstrar é o prepared statement
			// sozinho barrando a injeção.
			mysqli_stmt_bind_param( $stmt, "s", $id );
			mysqli_stmt_execute( $stmt );

			// bind_result + fetch em vez de mysqli_stmt_get_result(): o
			// get_result() depende do driver mysqlnd. A imagem do lab tem
			// (PHP 7.0.30, conferido), mas bind_result funciona em qualquer
			// build e não custa nada a mais.
			mysqli_stmt_bind_result( $stmt, $first, $last );

			while( mysqli_stmt_fetch( $stmt ) ) {
				$html .= "<pre>ID: " . htmlspecialchars( $id, ENT_QUOTES, 'UTF-8' ) .
				         "<br />First name: " . htmlspecialchars( $first, ENT_QUOTES, 'UTF-8' ) .
				         "<br />Surname: " . htmlspecialchars( $last, ENT_QUOTES, 'UTF-8' ) .
				         "</pre>";
			}

			mysqli_stmt_close( $stmt );
		}
	}
}

?>
