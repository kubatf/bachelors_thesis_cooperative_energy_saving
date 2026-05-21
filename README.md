Tento repozitář obsahuje zdrojové kódy v prostředí MATLAB pro praktickou část bakalářské práce zaměřené na energetickou optimalizaci a chytré řízení v kolejové dopravě.

## O projektu
Model simuluje interakce a energetické toky mezi trakčními jednotkami (na topologii linek 9 a 12 Dopravního podniku města Brna) a stacionárními bateriovými úložišti. 

Pro spravedlivé rozdělení vzniklých finančních a energetických úspor mezi jednotlivé aktéry (vozidla) je v modelu implementován aparát kooperativní teorie her, konkrétně výpočet exaktní Shapleyho hodnoty. Výsledky slouží jako podklad pro chytré řízení dopravy a prioritizaci vozidel s nejvyšším přínosem pro stabilitu sítě.

## Požadavky pro spuštění
Pro běh kódu je nezbytné mít nainstalováno:
* **MATLAB** (ideálně verze R2020a nebo novější).
* Knihovna **MatTuGames** (pro řešení her s přenositelnou užitnou hodnotou).

## Struktura souborů a spuštění
Simulace se opírá o následující soubory:
* `main.m` - Hlavní spouštěcí skript simulace.
* `uzly_brno.csv.csv` - Definice jednotlivých uzlů sítě (zastávky a topologie).
* `trasy_brno.csv` - Definice tras průjezdu jednotlivých vozidel.
* `krok_final.csv` - Skript/funkce zajišťující logiku výpočetního kroku.

**Postup spuštění:**
1. Naklonujte si tento repozitář nebo jej stáhněte jako ZIP.
2. Ujistěte se, že máte v MATLABu nainstalovanou a do cesty přidanou knihovnu MatTuGames.
3. Ponechte všechny soubory (`main`, `uzly_brno`, `trasy_brno`, `krok_final`) ve stejném pracovním adresáři.
4. Otevřete a spusťte soubor `main.m`.

## Licence a Autor
Tento projekt je licencován pod otevřenou licencí MIT.
František Kubát, student oboru Matematické inženýrství  
Vysoké učení technické v Brně (VUT)
