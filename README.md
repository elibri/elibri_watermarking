# Biblioteka Elibri Watermarking

## Opis

Biblioteka Elibri Watermarking, dostarczana jest w postaci pliku gema (dostępna na rubygems: https://rubygems.org/gems/elibri_watermarking ).
Użycie wymaga wcześniejszego kontaktu z serwisem Elibri (kontakt@elibri.com.pl), w celu otrzymania danych dostępowych do API.

## Zastosowanie

Biblioteka Elibri Watermarking upraszcza operacje wykonywane na API watermarkingu Elibri, abstrahując je do operacji wykonywanych na obiekcie Rubyego.

## Użycie

Aby użyć biblioteki w aplikacji Ruby on Rails, do pliku Gemfile należy dodać:

```gem 'elibri_watermarking```

aby użyć gema, poza aplikacją rails należy go zainstalować, komendą:
 
```gem install elibri_watermarking```

a następnie w konsoli w której chcemy użyć biblioteki wpisujemy: 

```ruby
require 'rubygems'
require 'elibri_watermarking'
```

Następnie musimy zainicjalizować bibliotekę, podając token i secret, otrzymane od Elibri:
```ruby
client = ElibriWatermarking::Client.new('token', 'secret')
```

Biblioteka daje nam do dyspozycji parę metod, odpowiadających wywołaniom metod API watermarkingu elibri:

* watermark (przyjmuje parametry: identyfikator [ISBN bez myślników lub record_reference], formaty [zapisana po przecinku lista formatów do watermarkingu - najcześciej "epub,mobi"], widoczny watermark [tekst widoczny na końcu każdego rozdziału], dopisek [krótki tekst dopisany do tytułu], supplier [numeryczny identyfikator dostawcy pliki], client_symbol [alfanumeryczny identyfikator zapisany przy transakcji], customer_ip [ip klienta końcowego, do celów statystycznych] - zwraca identyfikator transakcji, który klient zobowiązany jest zapisać i przechowywać) - wywołuje żądanie watermarku na podanym produkcie, w podanych formatach
* deliver (przyjmuje jeden parametr: identifykator transacji [otrzymany od watermark]) - wywołuje żądanie dostarczenia zwatermarkowanego pliku do bucketu klienta na s3
* watermark_and_deliver (przyjmuje parametry identyczne jak watermark, zwraca identyfikator transacji, który klient zobowiązany jest zapisać i przechowywać) - wywołuje watermarkowanie pliku, a następnie żąda jego dostarczenia do bucketu klienta na s3
* retry (przyjmuje jako parametr identyfikator transakcji, zwraca identyfikator nowej transakcji) - wywołuje żądanie ponowienia watermarkingu pliku, który został już ściągnięty (uwaga - sklep jest zobowiązany do przetrzymywanie zwatermarkowanego pliku przynajmniej przez 7 dni, dopiero po tym czasie możliwe jest wywołanie retry). Watermarking wykonywany jest z identycznymi parametrami, jak poprzedni. Klient zobowiązany jest zapisać i przechowywać nowy identyfikator transakcji. Po komendzie retry, niezbędne jest wywołanie komendy deliver w celu dostarczeni pliku do bucketu s3. Uwaga! Każdą transakcję retryować mozna tylko raz - w przypadku kolejnego żądania retry, konieczne jest podanie identyfikatora transakcji otrzymanego od poprzedniej komendy retry.
* available_files - zwraca listę dostępnych do watermarkingu przez klienta plików. Pliki są zwracane w postaci tablicy hashów, postaci:
```ruby
[
  {
    :record_reference => 'a'
    :publisher_name => 'b'
    :publisher_id => 1
    :isbn => '1234'
    :title => 'Tytuł',
    :formats => ["epub", "mobi"]
    :available_date => "data od kiedy plik jest dostępny - jeśli pole nie występuje, znaczy to, że plik jest dostępny"
    :suppliers => [1, 2, 3] #tablica zawierająca identyfikatora dostawców, mogących dostarczyć plik dla danego klienta
  }
]
```
* check_suppliers (przyjmuje jeden parametr: identyfikator [ISBN bez myślników lub record_reference]) - zwraca listę dostawców danego pliku, w postaci tablicy zawierającej numeryczne identyfikatory dostawców
* get_supplier (przyjmuje jeden parametr: numeryczny identyfikator dostawcy w systemie eLibri) - zwraca nazwę dostawcy o podanym identyfikatorze

## Błędy

Wywołanie poszczególnych metod może spowodować wywołanie jednego z następujących wyjątków:

* ParametersError - do serwera zostały wysłane złe parametry
* AuthenticationError - podany został zły token lub zły sig
* AuthorizationError - podany klient nie ma dostępu żądanego produktu, lub ten produkt nie istnieje, lub produkt nie posiada żądanego formatu
* ServerException - wystąpił wewnętrzny błąd serwera elibri
* RequestExpired - podany został zbyt stary request (request ważny jest 60 sekund)

Wszystkie te wyjątki, dziedziczą po klasie ElibriException, a także zawierają w treści opis błędu otrzymanego od API.

## Odebranie pliku

Po wywołaniu komendy deliver, plik zostaje załadowany do bucketu s3 (dane dostępowego do niego, otrzymacie Państwo podczas zakładania konta API). Sklep zobowiązany jest ściągnąć zwatermarkowany plik z bucketu s3 i przechowywać go po swojej stronie przez minimum 7 dni.
Plik zawsze będzie nazwany zgodnie z następującą konwencją:

```
trans_id.format
```

gdzie trans_id to identyfikator transakcji w systemie elibri (otrzymany podczas zlecania watermarkingu), a format to jeden z: epub, mobi.


Przykładowy kod umożliwiający odczytanie i zapisanie na własnym serwerze zwatermarkowanego pliku z bucketu s3:
```ruby
require 'rubygems'
require 'aws-sdk'

s3 = AWS::S3.new(:access_key_id => 'amazon access key', :secret_access_key => 'amazon secret key')
File.open('ścieżka do pliku docelowego na serwerze', 'w') do |f|
  f.puts s3.buckets['nazwa bucketu otrzymana przy rejestracji'].objects["identyfikator transacji.żądany format"].read
end
```

## Powiadomienie o dostępności pliku

Po wykonaniu polecenia deliver, plik zostanie umieszczony w buckecie s3. Sklep zostanie powiadomiony o tym fakcie, za pomocą requestu na podany przez niego endpoint.

Request jest typu post, zawiera w swojej treści identyfikator ukończonej transakcji - po jego otrzymaniu sklep powinien odebrać plik z bucketu s3 i zapisać go u siebie na serwerze.