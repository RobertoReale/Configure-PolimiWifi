# Configure-PolimiWifi

Script PowerShell per la configurazione automatica delle reti WiFi del Politecnico di Milano utilizzando l'autenticazione tramite certificato (TLS).

## Descrizione

Questo script automatizza la configurazione delle seguenti reti WiFi del Politecnico di Milano:
- polimi-protected
- polimi_protected
- eduroam

Lo script implementa il metodo di **Configurazione con certificato (TLS)** seguendo esattamente la [guida ufficiale del Politecnico di Milano per Windows](https://www.ict.polimi.it/wifi/connessione-permanente/). 

> **NOTA**: Questo script implementa il metodo di configurazione con certificato (TLS) e NON il metodo di Configurazione con Credenziali Polimi (TTLS). Entrambi i metodi sono descritti alla pagina [Connessione Permanente](https://www.ict.polimi.it/wifi/connessione-permanente/) del Politecnico di Milano.

## Prerequisiti

1. Sistema operativo Windows
2. Privilegi di amministratore
3. Account Polimi attivo
4. Certificato di rete valido (vedi sezione installazione)

## Installazione

### 1. Ottenere il Certificato

Prima di eseguire lo script, è necessario scaricare e installare un certificato valido:

1. Vai alla pagina di [richiesta certificato](https://aunicalogin.polimi.it/aunicalogin/getservizio.xml?id_servizio=2108) (o cerca "Richiesta certificati e autocertificazione" nei SERVIZI ONLINE)
2. Effettua il login con le tue credenziali Polimi
3. **IMPORTANTE**: Annota la password del certificato che ti viene mostrata
4. Installa il certificato:
   - Fai doppio click sul file scaricato (normalmente nella cartella download)
   - Clicca "Avanti"
   - Inserisci la password del certificato quando richiesto
   - Continua cliccando "Avanti" mantenendo le impostazioni predefinite
   - Clicca "Fine"

### 2. Scaricare lo Script

1. Scarica il file `Configure-PolimiWifi.ps1` da questo repository
2. Salva il file in una directory a tua scelta

## Utilizzo

1. Apri PowerShell come Amministratore
2. Naviga alla directory dove hai salvato lo script
3. Esegui:
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Configure-PolimiWifi.ps1
```

### Primo Accesso alla Rete

Al primo tentativo di connessione alle reti configurate:
1. Ti verrà richiesto se vuoi collegarti utilizzando il tuo certificato
2. Seleziona il certificato
3. Come nome utente, inserisci: `codicepersona@polimi.it` (esempio: `12345678@polimi.it`)

## Risoluzione dei Problemi

Se incontri problemi:
1. Verifica di aver installato correttamente il certificato
2. Controlla che il certificato non sia scaduto
3. Assicurati di utilizzare il formato corretto per il nome utente
4. Se necessario, prova a rimuovere manualmente le configurazioni di rete esistenti

## Disclaimer

Questo script è fornito "così com'è", senza garanzie di alcun tipo. L'autore non si assume alcuna responsabilità per eventuali problemi o danni derivanti dall'utilizzo di questo script.

Questo è un progetto non ufficiale e non è affiliato al Politecnico di Milano. Per la configurazione ufficiale, fare riferimento alla [documentazione ufficiale](https://www.ict.polimi.it/wifi/connessione-permanente/).

## Licenza

MIT License - Vedi il file LICENSE per i dettagli.
