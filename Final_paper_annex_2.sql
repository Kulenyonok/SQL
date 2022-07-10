--���������� 2
--������� �������� �. �.

--������� 1
/* ����������� ������� ���������� ���������� � ����� ������ � ������� ��������� count � ���������� �� �������.
����� ������� �������� � ������� Where �������� ������, ��� ���-�� ���������� > 1. ������� �������� ������� � ���-�� ���������� � ���. */

select *
from (select city, count(airport_name) as co
	from airports
	group by city) p1
where co > 1

--������� 2
/* � ���������� � ������� ������� ������� ��������� ������ ����� ���� ���������, ������� ������������ �������� ��������,
��������� dense_rank() �� ������, ���� ����� �������� ��������� � ����� ������� ������� flights �� ������� aircraft_code.
� �������� ������ ����� ������ �� ����������, ������� �� dense_rank() = 1 � ������� ������ ���������� ���� ���������� ������ */

select distinct p1.departure_airport
from (select f.departure_airport, 
		dense_rank() over(order by "range" desc) as ra
	from aircrafts a
	join flights f on f.aircraft_code = a.aircraft_code) p1
where p1.ra = 1

--������� 3
/* � ������ �������� ��� �����, �������� �� ������� ���� ��������, ���� ��� ������������.
 ����� �������� ������� � id ����� � ������ � �������� ������ �������� (���������� ����� - ����������� �����).
 ����� ��������� �� ������� �������� �� �������� � �������� � ���������� limit ������ ������ ������ 10 �������
 */

select flight_id, (actual_departure - scheduled_departure) as time1 
from flights f 
where status = 'Arrived' or status = 'Departed'
order by time1 desc
limit 10

--������� 4
/* ���������� ���� �����, ��� ��� ��� ���������� �������� NULL � ��� ������, ���� �� ������������ ��� ������ ���� ����������� ������.
������  �������� ������ �� ��������,
��� ������ ������ ����� �������� NULL, ������� ������ ������������, � ������� �������� ������ ���������.
 */

select distinct b.book_ref
from bookings b 
full join tickets t on t.book_ref = b.book_ref 
full join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.ticket_no is null

--������� 5

with c1 as ( --���
	select f.flight_id,
		f.departure_airport,
		f.actual_departure,
		(count(s.seat_no) - count(bp.seat_no)) as free_seats, --������� ���-�� ��������� ����
		count(s.seat_no) as seat1 -- ������� ���-�� ���� � ��������
	from flights f --������ ����� �� ������� flights
	join seats s on s.aircraft_code = f.aircraft_code --������� � �������� seats �� ������� aircraft_code
	left join boarding_passes bp on bp.seat_no = s.seat_no and bp.flight_id = f.flight_id --������� boarding_passes �� �������� seat_no � flight_id
	group by f.flight_id, f.departure_airport, f.actual_departure) --���������� � ����� � �������������� ���������� �������
select c1.flight_id,
	c1.departure_airport,
	c1.actual_departure,
	free_seats,
	round(((free_seats * 100)::float / seat1)::numeric(7,4), 1) as percents, --������� ���������� �����������, ��� ���� ������� ������� ��������� ������� �� �����, � ����� ����� ����������� � numeric
	(sum(count(bp.ticket_no)) over(partition by c1.departure_airport, c1.actual_departure::date order by c1.actual_departure)) as cumul -- ������� ������� ��� �������� �������������� �����  � ����������� ������� �� ��������� ������, ����� �� ���� ������ � ���� ������ "����" � ���������� �� ���� ������ � ���� timestamptz
from c1
left join boarding_passes bp on bp.flight_id = c1.flight_id --����� ������� �������� �����, ��� ��� ������, ��� ����� ��������� �������, ��� ������ ����� ��� ����� (�������� �� ���������� �������), � ����� �� �� ��������. � ����� � ���� � ������� ������� ���� ������ ticket_no
group by c1.departure_airport, c1.actual_departure, c1.flight_id, c1.free_seats, c1.seat1 --����������� � ����� � �������������� ���������� �-���

--������� 6
/* ������ ����� �� ������� ���������, �������� ������ ��������� � ����� ������� ���������� ����������� ����. �������:
 * ���-�� ��������� �� ������ ������ ��������� �������� �� 100, �������� � ������� �����, ����� �� ���-�� ���� ��������� (��� ����� ������ ���������)
 *  � �������� � ���� ������ numeric, ���� ��������� �� 2� ������ ����� ������� ���������� round. ��������� �� ������ ��������.
 */
select aircraft_code, round(((count(flight_id) * 100)::float / (select count(flight_id) from flights))::numeric(7,4), 2)
from flights f 
group by aircraft_code

--������� 7
/* � ������ cte ������� ����� ������� ����� �� ������-����� ��� ������� �����.
 * �� ������ cte ������� ����� ������� ����� �� �������-����� ��� ������� �����.
 * � �������� ������� ����� ������ �� cte1, ������� cte2, flights � airports, ���� ������� ������ ������ ���������� ��������.
 * ��������� �� �������, ��� �������� ����� ����� ������� ��������� � ����� ������� ������� <0.
 * ���������� �������� ������� � ���������� ���� �������.
 */
with c1 as(
	select flight_id, fare_conditions, max(amount) as econom
	from ticket_flights tf
	where fare_conditions = 'Economy'
	group by flight_id, fare_conditions),
c2 as(
	select flight_id, fare_conditions, min(amount) as business
	from ticket_flights tf 
	where fare_conditions = 'Business'
	group by flight_id, fare_conditions)
select distinct a.city
from c1
join c2 on c1.flight_id = c2.flight_id
join flights f on c1.flight_id = f.flight_id
join airports a on a.airport_code = f.arrival_airport 
where (c2.business - c1.econom) < 0

--������� 8
/* � ������ ������������� ������� ��� ��������� ������ ������ �������� ����� (����� ������ ���������� ������ ������, ��� ����������� ������� ���������� � �������� �������)
 * �� ������ ������������� ������� ��� ��������� ������ ���� ��������� ����� (����� ������ ���������� ������ ������, ��� ����������� ������� ���������� � �������� �������)
 * � ������� ������������� ������� ��� ��������� ���� �������.
 * � ���. ������� �� ���������, ���������� � ������� ������������� �������� ��������� �� ������� � ������� �������������, ����������� �� ���� inner join
 */
create view task_1 as
	select distinct f.flight_no,
		a.city 
	from flights f 
	join airports a on f.departure_airport = a.airport_code
	order by f.flight_no
	
create view task_2 as
	select distinct f.flight_no,
		a.city 
	from flights f 
	join airports a on f.arrival_airport = a.airport_code
	order by f.flight_no

create view task_3 as
	select a.city as c1 , a2.city as c2
	from airports a, airports a2
	where a.city <> a2.city
	
select *
from task_3
except
select task_1.city, task_2.city
from task_1 join task_2 on task_1.flight_no = task_2.flight_no

--������� 9
/* � ������ ��� ������� ��� ��������� ������� �� ���������� ������, ����� ����� ���������� � ������, ������� ������ ���������,
 * ������������� � ���� �� ��� ������� ������� � ���������� ��� ��������� ������������ �������� ��������, ��������� ������������� ������ �����.
 * �� ������ ��� ������� ��� ��������� �������� �� ���������� ������, ����� ����� ���������� � ������, ������� ������ ���������.
 * � ������� ��� ��������� ������� � ������ �� �������� � ������� � ������� ���1 � ���2 ��� ��������� ������ ���������.
 * � ��������� ��� ������������ ���������� ���� �����������, ��������� �� 3 ������ ����� ������� (�� ������).
 * �������� ������� ������� ��������, ���������� ����� �����������, ���������� ������� ����� ���������� �������, ������������� ������ ����, ������� ����� ���� �
 * � ������� �������� ��������� case ���������, ������� �� ������� �� ��������� ������ �� ��������� ���������.
 */
	
with c1 as(select distinct f.flight_no,
		a.airport_name,
		a.longitude,
		a.latitude,
		ai."range" 
	from flights f 
	join airports a on f.departure_airport = a.airport_code
	join aircrafts ai on ai.aircraft_code = f.aircraft_code 
	order by f.flight_no),
c2 as(select distinct f.flight_no,
		a.airport_name,
		a.longitude,
		a.latitude
	from flights f 
	join airports a on f.arrival_airport = a.airport_code
	order by f.flight_no),
c3 as (select c1.airport_name as air1, c2.airport_name as air2,
		radians(c1.longitude) as long1, radians(c1.latitude) as lat1,
		radians(c2.longitude) as long2, radians(c2.latitude) as lat2,
		c1."range" as dist_air
	from c1 join c2 on c1.flight_no = c2.flight_no),
c4 as (select (round(((acos(sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(long1 - long2)))*6371)::numeric(10,6), 3)) as dist,
		air1, air2, dist_air
	from c3)
select air1, air2, dist, dist_air,
	(dist_air - dist) as diff,
	case when (dist_air - dist) >= 0 then 'ok'
	else 'not ok'
	end
from c4

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	