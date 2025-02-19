# Realizacja procesora ODIN na FPGA

Dostosowanie projektu procesora neuronalnego ODIN do uruchomienia na płycie ZedBoard Zynq-7000 Development Board.

Projekt oparty o Vivado w wersji 2024.2.

## Aspekty fizyczne

Przed uruchomieniem należy podpiąć UART lub konwerter USB-UART to pinów:

- JB3 - tx
- JB4 - rx

Kierunek transmisji z punktu widzenia FPGA.

### Diody

- LD0 - włączony tryb konfiguracji
- LD1 - otrzymywanie danych po UART
- LD2 - utracono bajt po UART, wykonuj większe odstępy między komendami
- LD3-LD7 - podgląd 5 młodszych bitów wyjściowego AER

## Wgrywanie na płytę

Aby odtworzyć projekt w konsoli tcl programu vivado wykonaj:

```tcl
source create_project.tcl
```

Następnie wygeneruj i wgraj bitstream.

## Komendy

Komendy konfiguracji oraz sposób przesyłania wejściowych AER opisany został w pliku `rtl/axis_rx.sv`.
