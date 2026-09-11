<?php
/**
 * Correção do SQL Injection — CWE-89
 *
 * Substitui `targets/dvwa/vulnerabilities/sqli/source/low.php`.
 *
 * Achado original (OpenGrep, regra
 * php.lang.security.injection.tainted-sql-string.tainted-sql-string):
 * a variável $id vem de $_REQUEST e é concatenada diretamente na string da
 * query. Qualquer conteúdo enviado pelo usuário é interpretado como SQL —
 * `1' OR '1'='1` retorna a tabela inteira, e `1'; DROP TABLE users; --`
 * chega a alterar o schema.
 *
 * Código vulnerável (original do DVWA):
 *
 *     $id    = $_REQUEST[ 'id' ];
 *     $query = "SELECT first_name, last_name FROM users WHERE user_id = '$id';";
 *     $result = mysqli_query($GLOBALS["___mysqli_ston"], $query);
 *
 * Correção: prepared statement com bind de parâmetro. O driver envia a query
 * e os dados em mensagens separadas, então o valor de $id nunca é analisado
 * como SQL — ele é sempre tratado como dado, qualquer que seja o conteúdo.
 *
 * Repare que não há sanitização, escape nem lista de caracteres proibidos.
 * Essa é a diferença conceitual: escapar tenta neutralizar a entrada, o
 * prepared statement remove a possibilidade de a entrada virar código.
 */

if( isset( $_REQUEST[ 'Submit' ] ) ) {
	$id = $_REQUEST[ 'id' ];

	switch ($_DVWA['SQLI_DB']) {
		case MYSQL:
			$mysqli = $GLOBALS["___mysqli_ston"];

			// A query traz um placeholder, não o valor.
			$stmt = mysqli_prepare(
				$mysqli,
				"SELECT first_name, last_name FROM users WHERE user_id = ?"
			);

			if ( $stmt === false ) {
				break;
			}

			// "s" = o parâmetro é string. O valor viaja fora da query.
			mysqli_stmt_bind_param( $stmt, "s", $id );
			mysqli_stmt_execute( $stmt );

			$result = mysqli_stmt_get_result( $stmt );

			while( $row = mysqli_fetch_assoc( $result ) ) {
				$first = $row["first_name"];
				$last  = $row["last_name"];

				// htmlspecialchars evita que o dado vindo do banco vire HTML
				// na página. É defesa contra XSS (CWE-79) — problema distinto
				// do SQL Injection, mas que aparece no mesmo fluxo.
				echo "<pre>ID: " . htmlspecialchars( $id, ENT_QUOTES, 'UTF-8' ) .
				     "<br />First name: " . htmlspecialchars( $first, ENT_QUOTES, 'UTF-8' ) .
				     "<br />Surname: " . htmlspecialchars( $last, ENT_QUOTES, 'UTF-8' ) .
				     "</pre>";
			}

			mysqli_stmt_close( $stmt );
			break;

		case SQLITE:
			global $sqlite_db_connection;

			$stmt = $sqlite_db_connection->prepare(
				'SELECT first_name, last_name FROM users WHERE user_id = :id'
			);
			$stmt->bindValue( ':id', $id, SQLITE3_TEXT );
			$result = $stmt->execute();

			if ( $result !== false ) {
				while( $row = $result->fetchArray() ) {
					$first = $row["first_name"];
					$last  = $row["last_name"];

					echo "<pre>ID: " . htmlspecialchars( $id, ENT_QUOTES, 'UTF-8' ) .
					     "<br />First name: " . htmlspecialchars( $first, ENT_QUOTES, 'UTF-8' ) .
					     "<br />Surname: " . htmlspecialchars( $last, ENT_QUOTES, 'UTF-8' ) .
					     "</pre>";
				}
			}
			break;
	}
}

?>
