-- 1. Должен быть комментарий в шапке объекта
create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
as
set nocount on
begin

	-- 2. Все переменные должны задаваться в одном объявлении
	-- 3. Рекомендуется при объявлении типов не использовать длину поля max
	declare 
		@RowCount int = (select count(*) from syn.SA_CustomerSeasonal)
		,@ErrorMessage varchar(1000)

	-- 4. Коммментарий должен быть на одном уровне с кодом, к которому он относится
	-- Проверка на корректность загрузки
	if not exists (
		-- 5. Внутри скобок код должен быть смещён на один таб
		select 1
		-- 6. Не правильный алиас. Должен быть "imf". Не "if", т.к. это системное слово
		from syn.ImportFile as imf
		where imf.ID = @ID_Record
			and imf.FlagLoaded = cast(1 as bit)
	)
		begin
			set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'

			raiserror(@ErrorMessage, 3, 1)
			return
		end

	CREATE TABLE #ProcessedRows(ActionType varchar(255), ID int)
	
	--Чтение из слоя временных данных
	select
		cc.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(cs.DateBegin as date) as DateBegin
		,cast(cs.DateEnd as date) as DateEnd
		,cd.ID as ID_dbo_CustomerDistributor
		,cast(isnull(cs.FlagActive, 0) as bit) as FlagActive
	into #CustomerSeasonal
	-- 7. Пропущено "as". syn.SA_CustomerSeasonal as cs
	-- 8. Как я понимаю, во всём запросе вместо алиаса "sa" должен быть алиас "cs". 
	-- Для таблицы syn.SA_CustomerSeasonal правильный алиас "cs"
	from syn.SA_CustomerSeasonal as cs
		join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = cs.Season
		join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		-- 9. Сперва указываем поле присоединяемой таблицы	
		join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType
	where try_cast(cs.DateBegin as date) is not null
		and try_cast(cs.DateEnd as date) is not null
		and try_cast(isnull(cs.FlagActive, 0) as bit) is not null

	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной
	select
		-- 10. Снова в запросе везде вместо алиаса "cs" написан "sa". Нужно исправлять
		cs.*
		,case
			-- 11. "then" везде должен быть перенесён на следующую строку и сдвинут на один таб
			when cc.ID is null 
				then 'UID клиента отсутствует в справочнике "Клиент"'
			when cd.ID is null 
				then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null 
				then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null 
				then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(cs.DateBegin as date) is null 
				then 'Невозможно определить Дату начала'
			when try_cast(cs.DateEnd as date) is null 
				then 'Невозможно определить Дату начала'
			when try_cast(isnull(cs.FlagActive, 0) as bit) is null 
				then 'Невозможно определить Активность'
		end as Reason
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
		-- 12. Все виды join пишутся с одним отступом. При сдвиге также нужно будет сдвинуть и "and'ы"
		left join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
	-- 13. "and" не был перенесён на следующую строку
		left join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor 
			and cd.ID_mapping_DataSource = 1
		left join dbo.Season as s on s.Name = cs.Season
		left join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(cs.DateBegin as date) is null
		or try_cast(cs.DateEnd as date) is null
		or try_cast(isnull(cs.FlagActive, 0) as bit) is null
-- 14. Две пустые строки перед "end" лишние
end
