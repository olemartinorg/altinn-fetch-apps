## Script to fetch all running Altinn 3 apps

This script fetches all repositories and source code for running Altinn 3 apps in the tt02 and prod environments, and makes sure they are updated to the latest released version in that environment.

1. Velg en passende tom mappe å sjekke ut koden i.
```sh
git clone git@github.com:olemartinorg/altinn-fetch-apps.git
```
2. Kjør scriptet for å laste ned til et passende mappenavn (vi har valgt `all-apps`)
```sh
mkdir all-apps
./altinn-fetch-apps/fetch.sh all-apps
```

## Kjøre verifikasjoner
Nå har du alle filene til alle appene liggende på disk, og kan bruke vscode eller andre søkeverktøy til å finne bruk av apier, eller det du måtte ønske å verifisere

### Bruk testkode fra `app-frontentd-react` 
I `app-frontend-react` ligger det eksempel kode som sjekker status for ulike ting i alle apper.
I app-frontend-react, kopier template.env -> .env (om du ikke har gjort det fra før av) og sett ALTINN_ALL_APPS_DIR til en absolutt sti til mappa du oppretta der alle appene ligger (eg: `all-apps`).
Kj￸r tester som bruker dette konseptet, f.eks. src/utils/layout/schema.test.ts. Skal man sjekke f.eks. hvilke apper som har satt en gitt parameter på Input/TextArea-komponentene sine (som ble diskutert her, pleier jeg å utvide testen med litt egen kode:
          for (const component of (layout as any).data.layout) {
            if (component.type.toLowerCase() === 'input' || component.type.toLowerCase() === 'textarea') {
              if (component.maxLength !== undefined) {
                debugger;
              }
            }
          }
Når jeg kjørte denne med debuggeren på, fant jeg mange komponenter som setter maxLength. PS: Husk å sjekke komponent-typer uavhengig av uppercase/lowercase - vi fikser det når vi tolker layout i app-frontend slik at vi slipper å sjekke ellers i koden, men disse layout-filene er ikke tolket slik enda.

### TODO
- Delete checked-out apps no longer in the environment