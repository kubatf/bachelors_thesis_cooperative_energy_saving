function [v, sh_val, hra] = krok_final(E, typ, C_max, C_nabito, P_max)
   
    n = length(E);
    v = zeros(1, 2^n - 1);
    
    eta_TT = 0.95; 
    eta_TB = 0.90;
    eta_BT = 0.98;
    eta_TS = 0.80;
    eta_ST = 0.80;
    
    c_i = zeros(1, n);
    for i = 1:n
        if typ(i) == 1
            c_i(i) = max(E(i), 0);
        end
    end
    
    for k = 1:(2^n - 1)
        S = bitget(k, 1:n) == 1;
        
        e_S     = E(S);
        typ_S   = typ(S);
        c_nab_S = C_nabito(S);
        c_max_S = C_max(S);
        p_max_S = P_max(S);
        
        vybrano_z_bemu = 0;
        
        % KROK 1: BEMU deficit -> vlastní baterie
        for ii = 1:sum(S)
            if typ_S(ii) ~= 1 || c_max_S(ii) == 0 || e_S(ii) <= 0
                continue; 
            end
            vydej       = min(c_nab_S(ii), p_max_S(ii));
            prijato     = min(e_S(ii), vydej * eta_BT);
            c_nab_S(ii) = c_nab_S(ii) - (prijato / eta_BT);
            e_S(ii)     = e_S(ii) - prijato;
            
            vybrano_z_bemu = vybrano_z_bemu + prijato;
        end
        
        % KROK 2: Vlak -> Vlak
        generators = find(e_S < 0 & typ_S == 1);
        [~, sort_idx] = sort(c_max_S(generators));
        generators = generators(sort_idx);
        for ni = generators
            for pi = find(e_S > 0 & typ_S == 1)
                if e_S(ni) >= 0 || e_S(pi) <= 0
                    continue; 
                end
                mozno   = min(e_S(pi), abs(e_S(ni)) * eta_TT);
                e_S(pi) = e_S(pi) - mozno;
                e_S(ni) = e_S(ni) + (mozno / eta_TT);
            end
        end
        
        ulozeno_do_bemu = 0;
        
        % KROK 3: BEMU přebytek -> vlastní baterie
        for ii = 1:sum(S)
            if typ_S(ii) ~= 1 || c_max_S(ii) == 0 || e_S(ii) >= 0
                continue; 
            end
            ulozit      = min([abs(e_S(ii)) * eta_TB, c_max_S(ii) - c_nab_S(ii), p_max_S(ii)]);
            c_nab_S(ii) = c_nab_S(ii) + ulozit;
            e_S(ii)     = e_S(ii) + (ulozit / eta_TB);
            
            ulozeno_do_bemu = ulozeno_do_bemu + ulozit;
        end
        
        idx_bat        = find(typ_S == 2);
        ulozeno_do_bat = 0;
        vybrano_z_bat  = 0;
        
        % KROK 4: Staniční baterie -> Vlak
        for bi = idx_bat
            for pi = find(e_S > 0 & typ_S == 1)
                if e_S(pi) <= 0 || c_nab_S(bi) <= 0
                    continue; 
                end
                vydej       = min(c_nab_S(bi), p_max_S(bi));
                prijato     = min(e_S(pi), vydej * eta_ST);
                e_S(pi)     = e_S(pi) - prijato;
                c_nab_S(bi) = c_nab_S(bi) - (prijato / eta_ST);
                
                vybrano_z_bat = vybrano_z_bat + prijato;
            end
        end
        
        % KROK 5: Vlak -> Staniční baterie
        for ni = find(e_S < 0 & typ_S == 1)
            for bi = idx_bat
                volno = c_max_S(bi) - c_nab_S(bi);
                if e_S(ni) >= 0 || volno <= 0
                    continue; 
                end
                ulozit      = min([volno, p_max_S(bi), abs(e_S(ni)) * eta_TS]);
                e_S(ni)     = e_S(ni) + (ulozit / eta_TS);
                c_nab_S(bi) = c_nab_S(bi) + ulozit;
                
                ulozeno_do_bat = ulozeno_do_bat + ulozit;
            end
        end
        
        nakup_ze_site = sum(e_S(e_S > 0 & typ_S == 1));
        
        c_S  = nakup_ze_site ...
               + vybrano_z_bat + vybrano_z_bemu ...
               - ((ulozeno_do_bat * eta_ST) + (ulozeno_do_bemu * eta_BT));
               
        v(k) = sum(c_i(S)) - c_S;
    end
    
    hra = TuGame(v);
    sh_val = ShapleyValue(hra);
end