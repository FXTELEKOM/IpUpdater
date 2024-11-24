# IpUpdater

IP/tartományfrissítő script az FXTELEKOM VPN-hez.

Ezt a scriptet akkor érdemes futtatnod, amikor frissülnek az IP-k a szolgáltatásban.
Erről mindig értesítünk a Discord csatornánkon. :)
A script automatikusan frissíti a WireGuard konfigurációs fájlodat a kiválasztott szolgáltatások IP-tartományaival.

# Használat

## Script futtatása interaktív módban (Ajánlott)

> Ez az ajánlott mód azok számára, akik nem biztosak benne, hogy pontosan mit csinálnak.

1. Nyiss egy Windows Terminalt vagy PowerShell-t!

2. Másold be ezt a parancsot:

 ```shell
iex "& { $(iwr -useb 'https://raw.githubusercontent.com/FXTELEKOM/IpUpdater/main/IpUpdate.ps1') }"`!
 ```

3. A script kérni fogja a WireGuard konfigurációs fájl elérési útját.

4. Megjelenik egy interaktív menü, ahol kiválaszthatod a kívánt szolgáltatásokat:
    - Használd a fel/le nyilakat a navigáláshoz.
    - Nyomd meg a szóközt a szolgáltatások kiválasztásához vagy törléséhez.
    - Nyomd meg az Enter gombot a megerősítéshez.
5. A script frissíti a konfigurációs fájlt a kiválasztott szolgáltatások IP-tartományaival.

**Nincs más dolgod, mint élvezni a gyors internetet :)**

## Script futtatása parancssori paraméterekkel

> Ha pontosan tudod, mit szeretnél, használhatod a scriptet nem interaktív módban is, ha megadod a szükséges paramétereket:

- `-ConfigPath`: A WireGuard konfigurációs fájl teljes elérési útja.
- `-SelectedServices`: A kiválasztott szolgáltatások listája.
- `-All`: Az összes szolgáltatás kiválasztása.
- `-Verbose`: Részletes naplózás engedélyezése.

# Példák

### Példa: Minden szolgáltatás kiválasztása

```shell
.\IpUpdate.ps1 -All -ConfigPath C:\Users\Felhasználó\wg.conf
```

### Példa: Meghatározott szolgáltatások kiválasztása

```shell
.\IpUpdate.ps1 -ConfigPath C:\Users\Felhasználó\wg.conf  -SelectedServices 'Hunt: showdon EU', CS2 -verbose
```

### Példa: Részletes naplózás bekapcsolása

```shell
.\IpUpdate.ps1 -All -ConfigPath C:\Users\Felhasználó\wg.conf -Verbose
```

### Teljes segítség megjelenítése

A script teljes dokumentációjának megtekintéséhez futtasd:

```shell
Get-Help .\IpUpdate.ps1 -Detailed
```

# Hibakezelés

- Érvénytelen konfigurációs fájl: Ha a megadott konfigurációs fájl nem létezik vagy nem elérhető, a script hibaüzenetet
  ad és leáll.
- Érvénytelen szolgáltatásnév: Ha olyan szolgáltatásnevet adsz meg, ami nem létezik, a script figyelmeztetést ad és
  kihagyja azt.
- Hálózati hibák: Ha a script nem tudja letölteni az IP-listákat, hibaüzenetet ad és leáll.