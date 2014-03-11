
create or replace function replikuj_formy_platnosci() returns trigger as $$ -- $$ lub $body$ oznacza ciało funkcji/metody, tzn. rozpoczęcie procedury tak jak widać
	declare --deklaracja
		nil text; -- zmienna typu text (string)
		-- nil to przykładowa nazwa, ponieważ funkcie dblink_connect, dblink_exec wracają jakieś informacje typu udało się OK,
		-- lub niepowodzenie trzeba użyć jakieś zmiennej która będzie odbierać te dane (trigger nie może otrzymywać takich danych) wszystkie funkcje muszą być 
		-- typu void, czyli nie zwracające niczego
	begin -- rozpoczęcie procedury
		select dblink_connect('r_formy_platnosci','dbname=hubert user=marcin password=123') into nil; -- tworzenie połaczenia o nazwie r_formy_platnosci do bazy hubert
		-- new - przechowuje dane typu record po wykonaniu polecenia insert lub update, w przypadku insert będzie zawierać wszystkie pola/kolumny wprowadzanego wiersza, przy update tylko te zmodyfikowane
		-- old - przechowuje dane typu record po wykonaniu polecenia delete lub update, w przypadku update będzie zawierać pola/kolumny wiersza które zostały zmodyfikowane (przechowuje wcześniejsze dane kolumn wiersza)
		-- jeśli mamy kolumnę o nazwie "platnosc" to wartość przed modyfikacją będzie dostępna przez zapis - old.platnosc, na nowa wartość - new.platnosc
		if (TG_OP = 'UPDATE') then -- warunek dla przypadku kiedy trigger został wywołany przez update
			if (new.typ_platnosci is not null) then -- sprawdzamy czy new.jakas_nazwa została zmodyfikowana, jeśli nie to jest o wartości null
				-- wywołujemy polecenie update na połączeniu r_formy_platnosci modyfikując kolumnę na tabeli r_formy_platnosci w bazie hubert
				select dblink_exec('r_formy_platnosci','update r_formy_platnosci set typ_platnosci = ''' || new.typ_platnosci || ''' where id_formy_platnosci = ' || old.id_formy_platnosci) into nil;
			end if;
			if (new.numer_konta is not null) then -- jw
				select dblink_exec('r_formy_platnosci','update r_formy_platnosci set numer_konta = ''' || new.numer_konta || ''' where id_formy_platnosci = ' || old.id_formy_platnosci) into nil;
			end if;
			if (new.id_formy_platnosci is not null) then -- jw, modyfikujemy w tym przypadku klucz główny
				select dblink_exec('r_formy_platnosci','update r_formy_platnosci set id_formy_platnosci = ' || new.id_formy_platnosci || ' where id_formy_platnosci = ' || old.id_formy_platnosci) into nil;
			end if;
		end if;
		if (TG_OP = 'INSERT') then  -- jw, tyle że do polecenia insert
			-- jako że insert dodaje, a więc old nie istnieje (no bo nie ma takiego wiersza w bazie) czyli używamy new by dodać wszystkie wartości z wywołanego polecenia insert
			select dblink_exec('r_formy_platnosci','insert into r_formy_platnosci (id_formy_platnosci, typ_platnosci, numer_konta) values 
				(' || new.id_formy_platnosci || ',''' || new.typ_platnosci || ''',''' || new.numer_konta || ''');') into nil;
		end if;
		if (TG_OP = 'DELETE') then --jw, tu usuwamy wiersz
			select dblink_exec('r_formy_platnosci','delete from r_formy_platnosci where id_formy_platnosci = ' || old.id_formy_platnosci || ';') into nil;
		end if;
		select dblink_disconnect('r_formy_platnosci') into nil; -- na koniec rozłączamy się z bazą, czyli zamykamy połączenie r_formy_platnosci
		return;
		
		exception -- obsługa wyjątków, w przypadku jakiegoś nieprzewidzianego błędu
			when others then 
				select dblink_disconnect('r_formy_platnosci') into nil; -- jeśli wcześniej nawiązano połączenie należy je zakończyć inaczej utworzenie 
																		-- ponowne pod taką samą nazwą nie będzie możliwe, a co za tym idzie trigger replikacji przestanie działać i za każdym razem będzie zwracać błąd
				raise exception 'Problem z połączeniem dblink lub niewłaściwe dane.'; -- błąd który wyświetli się użytkownikowi
				return null;
	end; -- koniec procedury
$$ language plpgsql; -- nazwa języka

create trigger t_replikuj_formy_platnosci -- tworzenie triggera/wyzwalacza
after update or insert or delete -- after czyli po wykonaniu polecenia update lub insert lub delete, istnieje jeszcze before czyli przed wykonaniem pierwszy uruchomi się trigger
    on formy_platnosci -- na tabeli formy_platnosci
   for each row -- dla wszystkich wierszy (które po wykonaniu insert lub update lub delete uległy zmianą
execute procedure replikuj_formy_platnosci(); -- wykonuje procedurę replikuj_formy_platnosci(), czyli to co wyżej gdzie jest "create or replace function replikuj_formy_platnosci() returns trigger as $$" a kończy się na "$$ language plpgsql;"
