total_allocation = 15
discount_factor = 0.75

portions = [50]
spares = [105700]

while True:
    last_portion = portions[len(portions) - 1]

    # You can sell this
    sell = total_allocation / 100 * last_portion

    # We will obtain
    matic = sell * discount_factor

    # We have left
    left = total_allocation - sell

    if left < matic:
        break

    # We wasted
    wasted = left - matic

    next_portion = last_portion + 0.1
    if next_portion > 100:
        break

    portions.append(next_portion)
    spares.append(wasted)

lowest_spare_index = min(range(len(spares)), key=spares.__getitem__)
print("Sell percentage:", portions[lowest_spare_index])
print("----------------------------------------")
sell_amount = total_allocation * (portions[lowest_spare_index] / 100)
print("Pool (cSHARE/MATIC):", sell_amount, '|', sell_amount * 1000)
print("----------------------------------------")
print("COD to treasury:", total_allocation - sell_amount)
print("Waste to treasury:", spares[lowest_spare_index])
print("Total to treasury:", total_allocation - sell_amount + spares[lowest_spare_index])