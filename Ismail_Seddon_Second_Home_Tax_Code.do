* This do file builds the LA (unitary authority) x month panel from the four raw datasets, and then conducts causal analysis

* Part 0: Create a Welsh UA name crosswalk due to different name spellings and formattings in different datasets
*   PART 1: HMRC RTISA monthly wage data (4 raw LA-level exports)
*   PART 2: HM Land Registry Price Paid Data (national, 2014-2025)
*   PART 3: Second-home council tax premium schedule (LA x fiscal year)
*   PART 4: StatsWales second-home counts (LA x fiscal year)
*   PART 5: merge into all_pay_data.dta (ua_id x yearmonth)
* PART 6: Baseline TWFE
* PART 7: Remaining cauasal analysis and data viz creations

clear all
set more off

global root "C:\Users\ius\OneDrive - Case Western Reserve University"
global docs "C:\Users\ius\OneDrive - Case Western Reserve University\econ 398"
global out  "C:\Users\ius\OneDrive - Case Western Reserve University\code_sample\build"

cap mkdir "$out"


* Part 0: Create a Welsh UA name crosswalk due to different name spellings and formattings in different datasets


clear
input str30 raw_name str30 ua_name
"GWYNEDD"                 "GWYNEDD"
"CONWY"                   "CONWY"
"DENBIGHSHIRE"            "DENBIGHSHIRE"
"FLINTSHIRE"              "FLINTSHIRE"
"WREXHAM"                 "WREXHAM"
"POWYS"                   "POWYS"
"CEREDIGION"              "CEREDIGION"
"PEMBROKESHIRE"           "PEMBROKESHIRE"
"CARMARTHENSHIRE"         "CARMARTHENSHIRE"
"SWANSEA"                 "SWANSEA"
"BRIDGEND"                "BRIDGEND"
"CARDIFF"                 "CARDIFF"
"CAERPHILLY"              "CAERPHILLY"
"TORFAEN"                 "TORFAEN"
"MONMOUTHSHIRE"           "MONMOUTHSHIRE"
"NEWPORT"                 "NEWPORT"
"ISLEOFANGLESEY"          "ISLE OF ANGLESEY"
"ISLE OF ANGLESEY"        "ISLE OF ANGLESEY"
"NEATHPORTTALBOT"         "NEATH PORT TALBOT"
"NEATH PORT TALBOT"       "NEATH PORT TALBOT"
"VALEOFGLAMORGAN"         "THE VALE OF GLAMORGAN"
"VALE OF GLAMORGAN"       "THE VALE OF GLAMORGAN"
"THE VALE OF GLAMORGAN"   "THE VALE OF GLAMORGAN"
"RHONDDACYNONTAF"         "RHONDDA CYNON TAFF"
"RHONDDA CYNON TAF"       "RHONDDA CYNON TAFF"
"RHONDDA CYNON TAFF"      "RHONDDA CYNON TAFF"
"MERTHYRTYDFIL"           "MERTHYR TYDFIL"
"MERTHYR TYDFIL"          "MERTHYR TYDFIL"
"BLAENAUGWENT"            "BLAENAU GWENT"
"BLAENAU GWENT"           "BLAENAU GWENT"
end
tempfile ua_crosswalk
save `ua_crosswalk'


*    PART 1: HMRC RTISA monthly wage data (4 raw LA-level exports)

* I run a loop where 4 different wage exports are cleaned and formatted so that each shaped as one column per Welsh council and one row per month.

*once all 4 are cleaned they are merged together into one file.


local rtisa_files `" "rtisasep2025 LA Mean Pay.xlsx" "rtisasep2025 LA median pay.xlsx" "rtisasep2025 LA Aggragate Pay.xlsx" "rtisasep2025 LA exployees.xlsx" "'
local rtisa_vars "mean_pay med_pay agg_pay no_employees"

local wage_pieces
forvalues i = 1/4 {
    local f : word `i' of `rtisa_files'
    local v : word `i' of `rtisa_vars'

    import excel "$docs/`f'", firstrow clear

    rename IsleofAnglesey    pay_IsleofAnglesey
    rename Gwynedd           pay_Gwynedd
    rename Conwy             pay_Conwy
    rename Denbighshire      pay_Denbighshire
    rename Flintshire        pay_Flintshire
    rename Wrexham           pay_Wrexham
    rename Ceredigion        pay_Ceredigion
    rename Pembrokeshire     pay_Pembrokeshire
    rename Carmarthenshire   pay_Carmarthenshire
    rename Swansea           pay_Swansea
    rename NeathPortTalbot   pay_NeathPortTalbot
    rename Bridgend          pay_Bridgend
    rename ValeofGlamorgan   pay_ValeofGlamorgan
    rename Cardiff           pay_Cardiff
    rename RhonddaCynonTaf   pay_RhonddaCynonTaf
    rename Caerphilly        pay_Caerphilly
    rename BlaenauGwent      pay_BlaenauGwent
    rename Torfaen           pay_Torfaen
    rename Monmouthshire     pay_Monmouthshire
    rename Newport           pay_Newport
    rename Powys             pay_Powys
    rename MerthyrTydfil     pay_MerthyrTydfil

    reshape long pay_, i(Date) j(raw_name) string
    rename pay_ `v'
    destring `v', replace force

    gen yearmonth = monthly(Date, "MY")
    format yearmonth %tm

    replace raw_name = upper(trim(raw_name))
    merge m:1 raw_name using `ua_crosswalk', nogen keep(match)

    keep ua_name yearmonth `v'
    tempfile piece`i'
    save `piece`i''
    local wage_pieces `wage_pieces' `piece`i''
}

* Here I combine the 4 together 

use `piece1', clear
merge 1:1 ua_name yearmonth using `piece2', nogen
merge 1:1 ua_name yearmonth using `piece3', nogen
merge 1:1 ua_name yearmonth using `piece4', nogen

tempfile wage_panel
save `wage_panel'



*   PART 2: HM Land Registry Price Paid Data   (national, 2014-2025)

* This loop takes 16 raw Land Registry transaction files, it cleans and collapses the data into one row per transaction per month

*After this the cleaned data is merged together

local lr_files `" "pp-2014-part1 (1)" "pp-2014-part2 (1)" "pp-2015-part1 (2)" "pp-2015-part2 (2)" "pp-2016-part1 (1)" "pp-2016-part2 (1)" "pp-2017-part1 (1)" "pp-2017-part2 (1)" "pp-2018 (1)" "pp-2019 (1)" "pp-2020 (1)" "pp-2021 (1)" "pp-2022 (1)" "pp-2023 (2)" "pp-2024 (3)" "pp-2025 (2)" "'

local lr_pieces
local i = 0
foreach f of local lr_files {
    local i = `i' + 1

    import delimited "$root/`f'.csv", clear varnames(nonames) stringcols(_all)

    rename v2  price_str
    rename v3  date_str
    rename v5  property_type
    rename v14 raw_name

    destring price_str, gen(price) force
    gen date_only = substr(date_str, 1, 10)
    gen datevar   = date(date_only, "YMD")
    format datevar %td
    gen yearmonth = mofd(datevar)
    format yearmonth %tm

* exclude non-standard "Other" property type as these are non residential sales
    drop if property_type == "O"      

    replace raw_name = upper(trim(raw_name))
    merge m:1 raw_name using `ua_crosswalk', nogen keep(match)

    collapse (mean) mean_price = price (count) sales = price, by(ua_name yearmonth)

    tempfile lr_yr`i'
    save `lr_yr`i''
    local lr_pieces `lr_pieces' `lr_yr`i''
}

clear
foreach p of local lr_pieces {
    append using `p'
}


gen price_x_sales = mean_price * sales
collapse (sum) price_x_sales sales, by(ua_name yearmonth)
gen mean_price = price_x_sales / sales
drop price_x_sales

gen lnsales = log(sales)

tempfile price_panel
save `price_panel'


*   PART 3: Second-home council tax premium schedule (LA x fiscal year)

* Here I turn the fiscal year spreadsheet into a monthly panel dta

import excel "$root/Second home tax rates.xlsx", clear cellrange(A2:L44)

rename (_all) (raw_name premium_fy2014 premium_fy2015 premium_fy2016 premium_fy2017 premium_fy2018 premium_fy2019 premium_fy2020 premium_fy2021 premium_fy2022 premium_fy2023 premium_fy2024)

drop if missing(raw_name) 

destring premium_fy*, replace

replace raw_name = upper(trim(raw_name))
merge m:1 raw_name using `ua_crosswalk', nogen keep(match)

reshape long premium_fy, i(ua_name) j(fy_start)
rename premium_fy treat_intensity_100

* Expand each FY value out to its 12 calendar months
expand 12
bysort ua_name fy_start: gen month_in_fy = _n
gen calendar_month = mod(month_in_fy + 2, 12) + 1        
gen calendar_year  = fy_start + (calendar_month < 4)
gen yearmonth = ym(calendar_year, calendar_month)
format yearmonth %tm

keep ua_name yearmonth treat_intensity_100
duplicates drop

tempfile treatment_panel
save `treatment_panel'

*   PART 4: StatsWales second-home counts      (LA x fiscal year)

* Here I create the dta for the 2017 count of second homes per county to be used as a weighting

import excel "$root/num second homes.xlsx", clear cellrange(B1:D177)

rename (_all) (raw_name fy second_home_count)

drop if _n == 1                    
destring second_home_count, replace force

replace raw_name = upper(trim(raw_name))
merge m:1 raw_name using `ua_crosswalk', nogen keep(match)

preserve
    keep if fy == "2017-18"
    keep ua_name second_home_count
    rename second_home_count sh_count_april2017
    tempfile sh_count_2017
    save `sh_count_2017'
restore


*   PART 5: merge into all_pay_data.dta (ua_id x yearmonth)

* Merge all four pieces into one panel

* I drop the 3 months with no wage data, and drop UAs with unreliable 2017-18 second-home counts before finalizing.


use `wage_panel', clear
merge 1:1 ua_name yearmonth using `price_panel',   nogen
merge m:1 ua_name           using `sh_count_2017', nogen
merge 1:1 ua_name yearmonth using `treatment_panel', nogen keep(match) keepusing(treat_intensity_100)


replace treat_intensity_100 = 0 if missing(treat_intensity_100)


drop if inlist(yearmonth, ym(2014,4), ym(2014,5), ym(2014,6))



list ua_name if sh_count_april2017 == 0 | missing(sh_count_april2017), noobs
drop if sh_count_april2017 == 0 | missing(sh_count_april2017)

encode ua_name, gen(ua_id)
rename ua_name unitaryauthority
gen treatment_intensity = treat_intensity_100 / 100

order ua_id unitaryauthority yearmonth treatment_intensity treat_intensity_100 mean_pay med_pay agg_pay no_employees mean_price sales lnsales sh_count_april2017

save "$out/all_pay_data.dta", replace


* PART 6: Baseline TWFE

use "$out/all_pay_data.dta", clear

reghdfe lnsales treat_intensity_100, absorb(ua_id yearmonth) cluster(ua_id)



*  Result above is not statistically significant. I believe TWFE isn't the right estimator here staggered adoption, heterogeneous effects. Instead the heterogeneous robust did_multiplegt_dyn = de Chaisemartin & D'Haultfoeuille (2024), is used



* PART 7: Remaining causal analysis and data viz creations

** In this part I use AI (Claude Code) assistance for the extraction of the diff in diff results so I can make my clean twoway figure.
** AI is also used to assist me with the selecting from the different options available within twoway

capture which did_multiplegt_dyn
if _rc ssc install did_multiplegt_dyn


did_multiplegt_dyn lnsales ua_id yearmonth treatment_intensity, effects(10) placebo(10) cluster(ua_id) normalized weight(sh_count_april2017)


matrix list e(b)

matrix b = e(b)
matrix V = e(V)
local cn : colnames b
local k : word count `cn'

clear
set obs `k'
gen str20 coefname = ""
gen estimate = .
gen se = .

forvalues i = 1/`k' {
    local nm : word `i' of `cn'
    replace coefname = "`nm'" in `i'
    replace estimate = b[1,`i'] in `i'
    replace se = sqrt(V[`i',`i']) in `i'
}

gen period = .
replace period = real(subinstr(coefname, "Effect_", "", .))   if strpos(coefname, "Effect_")
replace period = -real(subinstr(coefname, "Placebo_", "", .)) if strpos(coefname, "Placebo_")

drop if missing(period)
keep period estimate se
sort period

gen ci_lower = estimate - 1.96*se
gen ci_upper = estimate + 1.96*se



local bracket_top    = -0.04
local bracket_bottom = -0.06
local bracket_dip    = -0.075


local label_y = 0.28

twoway (rcap ci_upper ci_lower period, lcolor(gs10) lwidth(medium)) ///
       (connected estimate period, mcolor(navy) msize(medium) msymbol(O) mfcolor(navy) ///
        lcolor(navy) lwidth(medium) lpattern(solid)) ///
       (pci `bracket_top' -6 `bracket_bottom' -6, lcolor(forest_green) lwidth(medthick)) ///
       (pci `bracket_bottom' -6 `bracket_bottom' -3, lcolor(forest_green) lwidth(medthick)) ///
       (pci `bracket_bottom' -3 `bracket_dip' -3, lcolor(forest_green) lwidth(medthick)) ///
       (pci `bracket_bottom' -3 `bracket_bottom' 0, lcolor(forest_green) lwidth(medthick)) ///
       (pci `bracket_top' 0 `bracket_bottom' 0, lcolor(forest_green) lwidth(medthick)), ///
       xline(-6, lcolor(maroon) lpattern(dash) lwidth(medium)) ///
       xline(0, lcolor(cranberry) lpattern(dash) lwidth(medium)) ///
       yline(0, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
       xlabel(-10(2)10, labsize(medium)) ///
       ylabel(-0.1(0.1)0.3, labsize(medium) angle(horizontal)) ///
       xtitle("Months Relative to Treatment (0 = First Treatment Period)", size(medium)) ///
       ytitle("Log Monthly Sales", size(medium)) ///
       title("Event Study: Treatment Effects on Log Property Sales", size(large) color(black)) ///
       subtitle("DID with Multiple Time Periods (Normalized)", size(medium)) ///
       legend(order(2 "Point Estimate" 1 "95% CI") position(6) rows(1) size(medium)) ///
       graphregion(color(white)) plotregion(color(white)) ///
       text(`label_y' -5.8 "Treatment Announced", place(e) size(small) color(maroon)) ///
       text(`label_y' 0.2 "Treatment Begins", place(e) size(small) color(cranberry)) ///
       text(`bracket_dip' -3 "Anticipation Effect", place(c) size(medium) color(forest_green)) ///
       note("Weighted by April 2017 Second Home Count. 95% Confidence Intervals shown.", size(small)) ///
       name(sales_graph, replace)

graph export "$out/event_study_lnsales.png", replace width(2400) height(1600)




use "$out/all_pay_data.dta", clear

preserve
    gen fy = year(dofm(yearmonth)) - (month(dofm(yearmonth)) < 4)
    collapse (mean) mean_price sh_count_april2017 (max) treat_intensity_100, ///
        by(ua_id unitaryauthority fy)

    drop if unitaryauthority == "PEMBROKESHIRE"

    gen ln_mean_price = log(mean_price)
    gen treatment_intensity = treat_intensity_100 / 100

    did_multiplegt_dyn ln_mean_price ua_id fy treatment_intensity, effects(8) placebo(4) cluster(ua_id) normalized weight(sh_count_april2017)
restore


matrix list e(b)

matrix b = e(b)
matrix V = e(V)
local cn : colnames b
local k : word count `cn'

clear
set obs `k'
gen str20 coefname = ""
gen estimate = .
gen se = .

forvalues i = 1/`k' {
    local nm : word `i' of `cn'
    replace coefname = "`nm'" in `i'
    replace estimate = b[1,`i'] in `i'
    replace se = sqrt(V[`i',`i']) in `i'
}

gen period = .
replace period = real(subinstr(coefname, "Effect_", "", .))   if strpos(coefname, "Effect_")
replace period = -real(subinstr(coefname, "Placebo_", "", .)) if strpos(coefname, "Placebo_")

drop if missing(period)
keep period estimate se
sort period

gen ci_lower = estimate - 1.96*se
gen ci_upper = estimate + 1.96*se

twoway (rcap ci_upper ci_lower period, lcolor(gs10) lwidth(medium)) ///
       (connected estimate period, mcolor(navy) msize(medium) msymbol(O) mfcolor(navy) ///
        lcolor(navy) lwidth(medium) lpattern(solid)), ///
       xline(0, lcolor(cranberry) lpattern(dash) lwidth(medium)) ///
       yline(0, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
       xlabel(-4(2)8, labsize(medium)) ///
       xtitle("Fiscal Years Relative to Treatment (0 = First Treatment Period)", size(medium)) ///
       ytitle("Effect on Log Mean Price", size(medium)) ///
       title("Event Study: Treatment Effects on Log Mean Price", size(large) color(black)) ///
       subtitle("DID with Multiple Time Periods (Normalized)", size(medium)) ///
       legend(order(2 "Point Estimate" 1 "95% CI") position(6) rows(1) size(medium)) ///
       graphregion(color(white)) plotregion(color(white)) ///
       text(0.04 0.05 "Treatment Begins", place(e) size(small) color(cranberry)) ///
       note("Weighted by April 2017 Second Home Count. 95% Confidence Intervals shown." ///
            "Pembrokeshire excluded.", size(small)) ///
       name(price_graph, replace)

graph export "$out/event_study_lnmeanprice.png", replace width(2400) height(1600)




use "$out/all_pay_data.dta", clear

did_multiplegt_dyn mean_pay ua_id yearmonth treatment_intensity, effects(10) placebo(10) cluster(ua_id) normalized weight(sh_count_april2017)

matrix list e(b)

matrix b = e(b)
matrix V = e(V)
local cn : colnames b
local k : word count `cn'

clear
set obs `k'
gen str20 coefname = ""
gen estimate = .
gen se = .

forvalues i = 1/`k' {
    local nm : word `i' of `cn'
    replace coefname = "`nm'" in `i'
    replace estimate = b[1,`i'] in `i'
    replace se = sqrt(V[`i',`i']) in `i'
}

gen period = .
replace period = real(subinstr(coefname, "Effect_", "", .))   if strpos(coefname, "Effect_")
replace period = -real(subinstr(coefname, "Placebo_", "", .)) if strpos(coefname, "Placebo_")

drop if missing(period)
keep period estimate se
sort period

gen ci_lower = estimate - 1.96*se
gen ci_upper = estimate + 1.96*se

twoway (rcap ci_upper ci_lower period, lcolor(gs10) lwidth(medium)) ///
       (connected estimate period, mcolor(navy) msize(medium) msymbol(O) mfcolor(navy) ///
        lcolor(navy) lwidth(medium) lpattern(solid)), ///
       xline(-6, lcolor(maroon) lpattern(dash) lwidth(medium)) ///
       xline(0, lcolor(cranberry) lpattern(dash) lwidth(medium)) ///
       yline(0, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
       xlabel(-10(2)10, labsize(medium)) ///
       xtitle("Months Relative to Treatment (0 = First Treatment Period)", size(medium)) ///
       ytitle("Monthly Mean Wages", size(medium)) ///
       title("Event Study: Treatment Effects on Mean Wages", size(large) color(black)) ///
       subtitle("DID with Multiple Time Periods (Normalized)", size(medium)) ///
       legend(order(2 "Point Estimate" 1 "95% CI") position(6) rows(1) size(medium)) ///
       graphregion(color(white)) plotregion(color(white)) ///
       text(5.1 -5.95 "Treatment Announced", place(e) size(small) color(maroon)) ///
       text(5.1 0.05 "Treatment Begins", place(e) size(small) color(cranberry)) ///
       note("Weighted by April 2017 Second Home Count. 95% Confidence Intervals shown.", size(small)) ///
       name(wage_graph, replace)

graph export "$out/event_study_meanpay.png", replace width(2400) height(1600)


