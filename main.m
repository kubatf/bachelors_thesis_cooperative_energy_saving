clc, clear, close all;
% =======================================================
% 1. DEFINICE SÍTĚ A FYZIKY
% =======================================================
uzly_data = readtable('uzly_brno.csv', 'Delimiter', ';');
mapa = readtable('trasy_brno.csv', 'Delimiter', ';'); %Vzdálenosti v m
uzly_X = uzly_data.X';
uzly_Y = uzly_data.Y';
uzly_Z = uzly_data.Z_m';

koef_vyska_t = (1000 * 9.81) / 3600000; % [kWh/m na 1 tunu]
davis_A = 0.003; davis_B = 0.00005; davis_C = 0.0001; %tabulkové hodnoty /3600

G = graph(mapa.Uzel_A, mapa.Uzel_B, mapa.Delka_m);

% =======================================================
% 2. DEFINICE HRÁČŮ (Vlaky a Baterie)
% =======================================================
vlaky(1).id = 1; vlaky(1).trasa = [shortestpath(G, 19, 1), 2, 3, shortestpath(G, 4, 14)];
vlaky(1).rychlost = 45; vlaky(1).hmotnost = 40;
vlaky(1).max_kapacita = 0; vlaky(1).kapacita = 0; vlaky(1).p_max = 0;

vlaky(2).id = 2; vlaky(2).trasa = [shortestpath(G, 14, 4), 3, 2, shortestpath(G, 1, 19)];
vlaky(2).rychlost = 45; vlaky(2).hmotnost = 40;
vlaky(2).max_kapacita = 40; vlaky(2).kapacita = 0; vlaky(2).p_max = 300;

vlaky(3).id = 3; vlaky(3).trasa = shortestpath(G, 20, 40);
vlaky(3).rychlost = 45; vlaky(3).hmotnost = 40;
vlaky(3).max_kapacita = 0; vlaky(3).kapacita = 0; vlaky(3).p_max = 0;

vlaky(4).id = 4; vlaky(4).trasa = shortestpath(G, 40, 20);
vlaky(4).rychlost = 45; vlaky(4).hmotnost = 40;
vlaky(4).max_kapacita = 40; vlaky(4).kapacita = 0; vlaky(4).p_max = 300;


for i = 1:length(vlaky)
    vlaky(i).aktualni_krok = 1;
    vlaky(i).ujeto_m = 0;
end

bat(1).id = 1; bat(1).max = 300; bat(1).kapacita = 0; bat(1).poloha = 4;  bat(1).p_max = 600;

pocet_vlaku  = length(vlaky);
pocet_baterii = length(bat);
n_hracu      = pocet_vlaku + pocet_baterii;

% Účinnosti přenosů
eta = 0.85;
eta_TT = 0.95;  % Vlak -> Vlak
eta_TB = 0.90;  % Vlak -> vlastní baterie BEMU
eta_BT = 0.98;  % vlastní bat -> Vlak
eta_TS = 0.80;  % Vlak -> staniční baterie
eta_ST = 0.80;  % staniční bat -> Vlak


barvy_pro_vlaky = lines(pocet_vlaku);
if pocet_vlaku >= 3
    barvy_pro_vlaky(3, :) = [0.15, 0.55, 0.20];
end

% =======================================================
% 3. PŘÍPRAVA GRAFICKÉHO ROZHRANÍ
% =======================================================
fig_mapa = figure('Name', 'Smart Grid Simulátor', 'NumberTitle', 'off', ...
                  'Position', [100 100 1000 600], 'Color', 'white');
hold on; axis equal; grid on;

stop_sim = false; 
btn_stop = uicontrol('Style', 'pushbutton', 'String', 'ZASTAVIT A VYHODNOTIT', ...
    'Position', [20 20 160 30], 'FontWeight', 'bold', 'ForegroundColor', 'w', 'BackgroundColor', [0.8 0 0], ...
    'Callback', 'stop_sim = true;');

minX = min(uzly_X); maxX = max(uzly_X);
minY = min(uzly_Y); maxY = max(uzly_Y);
padX = max(1, (maxX - minX) * 0.15);
padY = max(1, (maxY - minY) * 0.15);
xlim([minX - padX, maxX + padX]);
ylim([minY - padY, maxY + padY]);

set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', '#CCCCCC', 'LineWidth', 1);
title('', 'Color', 'k', 'FontSize', 14);
xlabel('X [100 m]', 'Color', 'k'); ylabel('Y [100 m]', 'Color', 'k');
for i = 1:height(mapa)
    idxA = find(uzly_data.ID == mapa.Uzel_A(i));
    idxB = find(uzly_data.ID == mapa.Uzel_B(i));
    plot([uzly_X(idxA), uzly_X(idxB)], [uzly_Y(idxA), uzly_Y(idxB)], '-', ...
        'Color', [0.6 0.6 0.6], 'LineWidth', 1.5);
end
h_stanice = scatter(uzly_X, uzly_Y, 40, [0.4 0.4 0.4], 'filled');
h_stanice.DataTipTemplate.DataTipRows(1).Label = 'X';
h_stanice.DataTipTemplate.DataTipRows(2).Label = 'Y';
h_stanice.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('', uzly_data.Nazev);
stupne_uzlu = degree(G);
for i = find(stupne_uzlu == 1)'
    text(uzly_X(i), uzly_Y(i) + (padY*0.15), uzly_data.Nazev{i}, ...
        'Color', 'k', 'FontSize', 8, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'Interpreter', 'none', 'FontWeight', 'bold');
end

body_vlaku = gobjects(1, pocet_vlaku);
for i = 1:pocet_vlaku
    body_vlaku(i) = plot(uzly_X(vlaky(i).trasa(1)), uzly_Y(vlaky(i).trasa(1)), ...
        'o', 'MarkerSize', 10, 'MarkerFaceColor', barvy_pro_vlaky(i,:), ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
end
h_highlight = plot(NaN, NaN, 'o', 'MarkerSize', 20, 'LineWidth', 2.5, 'Color', [0 0.6 0]);

casovy_text = text(minX - padX*0.8, maxY + padY*0.4, 'Čas: 0.0 min', ...
    'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0.5 0]);
uspora_text = text(maxX - padX*2.5, maxY + padY*0.4, 'Úspora sítě: 0.0 kWh', ...
    'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0.5 0]);

bat_texts = gobjects(1, pocet_baterii);
for b = 1:pocet_baterii
    bat_texts(b) = text(uzly_X(bat(b).poloha) + (padX*0.05), uzly_Y(bat(b).poloha) + (padY*0.05), ...
        '', 'FontWeight', 'bold', 'Color', [0 0 0.6], 'FontSize', 9);
end

% =======================================================
% 4. ČASOVÁ SMYČKA
% =======================================================
dt = 0.1;
dt_hodiny = dt / 60;
cas_celkem           = 0;
celkove_sh_val       = zeros(1, n_hracu);
celkova_spotreba_bez = 0;
celkovy_nakup_ze_site = 0;
cas_historie         = [];
spotreba_bez_historie = [];
nakup_historie       = [];
vykon_vlaku_historie = [];
energie_vlaku_kumul  = zeros(pocet_vlaku, 1);
energie_vlaku_kumul_historie = [];
sh_val_historie = [];
okamzita_hruba_spotreba_historie = [];
okamzity_nakup_site_historie = [];

while true
    if stop_sim
        disp('Simulace manuálně zastavena. Vykresluji výsledky...');
        break;
    end
    cas_celkem = cas_celkem + dt;
    vsechny_v_cili = true;

    E_vektor = zeros(1, pocet_vlaku);
    P_vektor = zeros(1, pocet_vlaku);

    % --- POHYB VLAKŮ A VÝPOČET ENERGIE ---
    for i = 1:pocet_vlaku
        k = vlaky(i).aktualni_krok;
        if k >= length(vlaky(i).trasa) 
            continue; 
        end
        vsechny_v_cili = false;

        u_A = vlaky(i).trasa(k);
        u_B = vlaky(i).trasa(k+1);
        idx = find((mapa.Uzel_A == u_A & mapa.Uzel_B == u_B) | (mapa.Uzel_B == u_A & mapa.Uzel_A == u_B));
        if isempty(idx)
            error('Kolej mezi uzlem %d a %d neexistuje.', u_A, u_B); 
        end

        delka_m = mapa.Delka_m(idx);
        krok_m = min((vlaky(i).rychlost / 60) * dt * 1000,  delka_m - vlaky(i).ujeto_m);
        vlaky(i).ujeto_m = vlaky(i).ujeto_m + krok_m;

        odpor_km = (davis_A * vlaky(i).hmotnost) + (davis_B * vlaky(i).hmotnost * vlaky(i).rychlost) + (davis_C * vlaky(i).rychlost^2);
        prevyseni_m = uzly_Z(u_B) - uzly_Z(u_A);
        E_hrana = ((delka_m / 1000) * odpor_km) + (prevyseni_m * vlaky(i).hmotnost * koef_vyska_t);
        E_krok = (E_hrana / delka_m) * krok_m;

        if E_krok < 0
            E_vektor(i) = E_krok * eta;  
        else
            E_vektor(i) = E_krok;
        end

        if krok_m > 0
            P_vektor(i) = E_vektor(i) / ((krok_m / 1000) / vlaky(i).rychlost);
        end

        procento = vlaky(i).ujeto_m / delka_m;
        if ~isvalid(body_vlaku(i)) 
            disp('Simulace přerušena.'); 
            return; 
        end
        set(body_vlaku(i), 'XData', uzly_X(u_A) + procento * (uzly_X(u_B) - uzly_X(u_A)), ...
                           'YData', uzly_Y(u_A) + procento * (uzly_Y(u_B) - uzly_Y(u_A)));

        if vlaky(i).ujeto_m >= delka_m - 1e-2
            vlaky(i).aktualni_krok = vlaky(i).aktualni_krok + 1;
            vlaky(i).ujeto_m = 0;
        end
    end

    if vsechny_v_cili 
        break; 
    end

    E_hraci = [E_vektor, zeros(1, pocet_baterii)];
    typ_hraci = [ones(1, pocet_vlaku), 2*ones(1, pocet_baterii)];
    C_max_hraci = [[vlaky.max_kapacita], [bat.max]];
    C_nab_hraci = [[vlaky.kapacita],     [bat.kapacita]];
    P_max_hraci = [[vlaky.p_max], [bat.p_max]];

    [~, sh_val, hra] = krok_final(E_hraci, typ_hraci, C_max_hraci, C_nab_hraci, P_max_hraci);
    celkove_sh_val = celkove_sh_val + sh_val;
    sh_val_historie(:, end+1) = sh_val';
    sh_val_vlaky = sh_val(1:pocet_vlaku);
    [max_sh, idx_max_sh] = max(sh_val_vlaky);
    if max_sh > 0
        x_akt = get(body_vlaku(idx_max_sh), 'XData');
        y_akt = get(body_vlaku(idx_max_sh), 'YData');
        set(h_highlight, 'XData', x_akt, 'YData', y_akt);
    else
        set(h_highlight, 'XData', NaN, 'YData', NaN);
    end

    spotreba_kroku = sum(E_hraci(E_hraci > 0 & typ_hraci == 1));
    celkova_spotreba_bez = celkova_spotreba_bez + spotreba_kroku;

    % KROK 1: BEMU deficit -> vlastní baterie
    for i = 1:pocet_vlaku
        if vlaky(i).max_kapacita <= 0 || E_hraci(i) <= 0
            continue; 
        end
        vydej = min(vlaky(i).kapacita, vlaky(i).p_max * dt_hodiny);
        prijato = min(E_hraci(i), vydej * eta_BT);
        vlaky(i).kapacita = vlaky(i).kapacita - (prijato / eta_BT);
        E_hraci(i) = E_hraci(i) - prijato;
    end

    % KROK 2: Vlak -> Vlak
    generators = find(E_hraci < 0 & typ_hraci == 1);
    [~, sort_idx] = sort(C_max_hraci(generators));
    generators = generators(sort_idx);
    for ni = generators
        for pi = find(E_hraci > 0 & typ_hraci == 1)
            if E_hraci(ni) >= 0 || E_hraci(pi) <= 0 
                continue; 
            end
            mozno = min(E_hraci(pi), abs(E_hraci(ni)) * eta_TT);
            E_hraci(pi) = E_hraci(pi) - mozno;
            E_hraci(ni) = E_hraci(ni) + (mozno / eta_TT);
        end
    end

    % KROK 3: BEMU přebytek -> vlastní baterie
    for i = 1:pocet_vlaku
        if vlaky(i).max_kapacita <= 0 || E_hraci(i) >= 0
            continue; 
        end
        ulozit = min([abs(E_hraci(i)) * eta_TB, vlaky(i).max_kapacita - vlaky(i).kapacita, vlaky(i).p_max * dt_hodiny]);
        vlaky(i).kapacita = vlaky(i).kapacita + ulozit;
        E_hraci(i) = E_hraci(i) + (ulozit / eta_TB);
    end

    % KROK 4: Staniční baterie -> Vlak
    for b = 1:pocet_baterii
        for pi = find(E_hraci > 0 & typ_hraci == 1)
            if E_hraci(pi) <= 0 || bat(b).kapacita <= 0
                continue; 
            end
            vydej  = min(bat(b).kapacita, bat(b).p_max * dt_hodiny);
            prijato = min(E_hraci(pi), vydej * eta_ST);
            E_hraci(pi)    = E_hraci(pi) - prijato;
            bat(b).kapacita = bat(b).kapacita - (prijato / eta_ST);
        end
    end

    % KROK 5: Vlak -> Staniční baterie
    for b = 1:pocet_baterii
        for ni = find(E_hraci < 0 & typ_hraci == 1)
            volno = bat(b).max - bat(b).kapacita;
            if E_hraci(ni) >= 0 || volno <= 0
                continue; 
            end
            ulozit = min([volno, bat(b).p_max * dt_hodiny, abs(E_hraci(ni)) * eta_TS]);
            E_hraci(ni)     = E_hraci(ni) + (ulozit / eta_TS);
            bat(b).kapacita = bat(b).kapacita + ulozit;
        end
    end

    nakup_kroku = sum(E_hraci(E_hraci > 0 & typ_hraci == 1));
    celkovy_nakup_ze_site = celkovy_nakup_ze_site + nakup_kroku;

    energie_vlaku_kumul = energie_vlaku_kumul + E_vektor';
    energie_vlaku_kumul_historie(:, end+1) = energie_vlaku_kumul;
    vykon_vlaku_historie(:, end+1) = P_vektor';
    cas_historie(end+1)            = cas_celkem;
    spotreba_bez_historie(end+1)   = celkova_spotreba_bez;
    nakup_historie(end+1)          = celkovy_nakup_ze_site;
    okamzita_hruba_spotreba_historie(end+1) = spotreba_kroku / (dt / 60);
    okamzity_nakup_site_historie(end+1)     = nakup_kroku / (dt / 60);

    set(casovy_text, 'String', sprintf('Čas: %0.1f min', cas_celkem));
    set(uspora_text, 'String', sprintf('Úspora sítě: %.1f kWh', celkova_spotreba_bez - celkovy_nakup_ze_site));
    for b = 1:pocet_baterii
        set(bat_texts(b), 'String', sprintf('Bat %d: %.1f kWh', bat(b).id, bat(b).kapacita));
    end
    drawnow; 
    pause(0.05);
end
% =======================================================
% 5. ZÁVĚREČNÉ GRAFY
% =======================================================
kategorie = cell(1, n_hracu);
for i = 1:pocet_vlaku
    if vlaky(i).max_kapacita > 0
        kategorie{i} = sprintf('BEMU %d', vlaky(i).id);
    else
        kategorie{i} = sprintf('Vlak %d', vlaky(i).id);
    end
end
for b = 1:pocet_baterii
    kategorie{pocet_vlaku + b} = sprintf('Bat %d (Uz %d)', bat(b).id, bat(b).poloha);
end

% --- GRAF 1: Shapleyho hodnoty ---
fig1 = figure('Name', 'Výsledky teorie her', 'Color', 'white');
b_plot = bar(celkove_sh_val, 'FaceColor', 'flat');
for k = 1:n_hracu
    if k <= pocet_vlaku
        b_plot.CData(k,:) = [0 0.45 0.74];
    else
        b_plot.CData(k,:) = [0.85 0.33 0.1];
    end
end
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', '#CCCCCC', 'FontSize', 12);
set(gca, 'XTickLabel', kategorie); grid on;
title('Celkové Shapleyho hodnoty hráčů', 'Color', 'k', 'FontSize', 14);
ylabel('Přiznaná úspora [kWh]', 'Color', 'k', 'FontSize', 12);

% --- GRAF 2: Kumulativní spotřeba ---
fig2 = figure('Name', 'Porovnání energetické efektivity', 'Color', 'white', 'Position', [200 200 800 400]);
hold on; grid on;
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', '#CCCCCC', 'FontSize', 11);
plot(cas_historie, spotreba_bez_historie, 'r--', 'LineWidth', 2, 'DisplayName', 'Hrubá spotřeba bez spolupráce');
plot(cas_historie, nakup_historie,        'b-',  'LineWidth', 2.5, 'DisplayName', 'Reálný nákup ze sítě');
fill([cas_historie, fliplr(cas_historie)], [spotreba_bez_historie, fliplr(nakup_historie)], 'g', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
title('Kumulativní spotřeba', 'Color', 'k', 'FontSize', 14);
xlabel('Čas simulace [min]', 'Color', 'k', 'FontSize', 11); ylabel('Kumulativní energie [kWh]', 'Color', 'k', 'FontSize', 11);
legend('Location', 'northwest', 'TextColor', 'k', 'Color', 'w', 'FontSize', 11);

% --- GRAF 3: Výkon a spotřeba jednotlivých vlaků ---
fig3 = figure('Name', 'Energetický profil vlaků', 'Color', 'white', 'Position', [250 150 900 700]);
hold on; grid on;
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', '#CCCCCC', 'FontSize', 12);
title('Průběh okamžitých výkonů', 'Color', 'k', 'FontSize', 13); ylabel('Výkon [kW]', 'Color', 'k');
for i = 1:pocet_vlaku
    plot(cas_historie, vykon_vlaku_historie(i,:), 'Color', barvy_pro_vlaky(i,:), 'LineWidth', 1.5, 'DisplayName', kategorie{i});
end
yline(0, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
legend('TextColor', 'k', 'Color', 'w', 'Location', 'best', 'NumColumns', 2);


% --- GRAF 4: Kumulativní spotřeba ---
fig4 = figure('Name', 'Průběh Shapleyho hodnot v čase', 'Color', 'white', 'Position', [300 250 900 400]);
hold on; grid on;
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', '#CCCCCC', 'FontSize', 12);
title('Kumulativní spotřeba hráčů', 'Color', 'k', 'FontSize', 13);
xlabel('Čas simulace [min]', 'Color', 'k'); ylabel('Kumulativní energie [kWh]', 'Color', 'k');
for i = 1:pocet_vlaku
    plot(cas_historie, energie_vlaku_kumul_historie(i,:), 'Color', barvy_pro_vlaky(i,:), 'LineWidth', 2.5, 'DisplayName', kategorie{i});
end
yline(0, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
legend('TextColor', 'k', 'Color', 'w', 'Location', 'best', 'NumColumns', 2);
yline(0, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
legend('TextColor', 'k', 'Color', 'w', 'Location', 'best', 'NumColumns', 2, 'FontSize', 11);

% --- 5. GRAF: Okamžitá spotřeba vs. Skutečný nákup ---
fig_peak = figure('Name', 'Peak Shaving', 'Position', [100, 100, 1000, 500], 'Color', 'white');
hold on; grid on;
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', '#CCCCCC', 'FontSize', 12);
plot(cas_historie, okamzita_hruba_spotreba_historie, '--r', 'LineWidth', 2);
plot(cas_historie, okamzity_nakup_site_historie, '-b', 'LineWidth', 2.5);
title('Okamžitá spotřeba a skutečný nákup', 'Color', 'k', 'FontSize', 16, 'FontWeight', 'bold');
xlabel('Čas simulace [min]', 'Color', 'k', 'FontSize', 12);
ylabel('Okamžitý odběr ze sítě [kW]', 'Color', 'k', 'FontSize', 12);
legend('Hrubá spotřeba', 'Skutečný nákup', 'Location', 'northeast', 'FontSize', 12, 'TextColor', 'k', 'Color', 'w');

% --- GRAF 6: Průběh Shapleyho hodnot v čase  ---
fig6 = figure('Name', '', 'Color', 'white', 'Position', [300 250 900 400]);
hold on; grid on;
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', '#CCCCCC', 'FontSize', 12);
title('Průběh Shapleyho hodnot', 'Color', 'k', 'FontSize', 13);
xlabel('Čas simulace [min]', 'Color', 'k', 'FontSize', 12); 
ylabel('Shapleyho hodnota [kWh/krok]', 'Color', 'k', 'FontSize', 12);
for i = 1:pocet_vlaku
    plot(cas_historie, sh_val_historie(i,:), 'Color', barvy_pro_vlaky(i,:), 'LineWidth', 1.5, 'DisplayName', kategorie{i});
end
for b = 1:pocet_baterii
    plot(cas_historie, sh_val_historie(pocet_vlaku + b, :), ...
        'Color', [0.85 0.33 0.1], 'LineWidth', 1.5, 'LineStyle', '--', ...
        'DisplayName', kategorie{pocet_vlaku + b});
end
yline(0, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
legend('TextColor', 'k', 'Color', 'w', 'Location', 'northeast', 'NumColumns', 2);