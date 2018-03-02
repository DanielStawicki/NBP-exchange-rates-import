
--==========================================================================================================================================================================================
--================================================================ Create fact table for exchange rates ====================================================================================
--==========================================================================================================================================================================================

use [SSIS_Scripts]
go

/****** Object:  Table [dbo].[Exchange_rates]    Script Date: 02-03-2018 08:20:24 ******/
set ansi_nulls on
go

set quoted_identifier on
go

create table [dbo].[Exchange_rates](
	[Rate_ID] [int] identity(1,1) not null,
	[Date] [date] not null,
	[Rate] [decimal](18, 4) not null,
	[NBP_line_name] [nvarchar](50) not null,
	[Create_date] [datetime] not null,
	[Update_date] [datetime] null,
 constraint [PK_Exchange_rates] primary key clustered 
(
	[Rate_ID] asc
)with (pad_index = off, statistics_norecompute = off, ignore_dup_key = off, allow_row_locks = on, allow_page_locks = on) on [PRIMARY]
) on [PRIMARY]
go

alter table [dbo].[Exchange_rates] add  constraint [DF_Exchange_rates_Create_date]  default (getdate()) for [Create_date]
go

--==========================================================================================================================================================================================
--======================================================================= Create tmp table =================================================================================================
--==========================================================================================================================================================================================

use [SSIS_Scripts]
go

/****** Object:  Table [dbo].[Exchange_rates_tmp]    Script Date: 02-03-2018 08:20:30 ******/
set ansi_nulls on
go

set quoted_identifier on
go

create table [dbo].[Exchange_rates_tmp](
	[Date] [date] not null,
	[Rate] [decimal](18, 4) not null,
	[NBP_line_name] [nvarchar](50) not null
) on [PRIMARY]
go

--==========================================================================================================================================================================================
--=========================================================== Create stored procedure that loads exchange rates ============================================================================
--==========================================================================================================================================================================================




USE [SSIS_Scripts]
GO

/****** Object:  StoredProcedure [dbo].[LoadXMLexchangeRates]    Script Date: 02-03-2018 08:22:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		<Daniel Stawicki>
-- Create date: <2018-02-21>
-- Description:	<Procedure saves data from NBP XML file with exchange rates into table [dbo].[Exchange_rates]>
-- =============================================
create procedure [dbo].[LoadXMLexchangeRates]
	-- Add the parameters for the stored procedure here
	@XML_rates nvarchar(max)
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;

	-- Insert statements for procedure here
	declare @XML as xml
		,@hDoc as int

	select @XML_rates = replace(@XML_rates, '<?xml version="1.0" encoding="UTF-8"?>', '<?xml version="1.0" encoding="UTF-16"?>')

	set @XML = @XML_rates;

	exec sp_xml_preparedocument @hDoc output
		,@XML;

	select No
		,EffectiveDate
		,Exchangerate
	into #MergeTable
	from openxml(@hDoc, 'ExchangeRatesSeries/Rates/Rate') with (
			No [nvarchar](20) 'No'
			,EffectiveDate [date] 'EffectiveDate'
			,Exchangerate [decimal](18, 4) 'Mid'
			);

	exec sp_xml_removedocument @hDoc;

	merge [dbo].[Exchange_rates] as Er
	using #MergeTable as Mt
		on (Er.DATE = Mt.EffectiveDate)
	when matched and (Er.Rate != Mt.Exchangerate or Er.NBP_line_name != Mt.No)
		then
			update
			set Er.Rate = Mt.Exchangerate
				,Er.NBP_line_name = Mt.No
				,Er.Update_date = getdate()
	when not matched by target
		then
			insert (
				[Date]
				,[Rate]
				,[NBP_line_name]
				)
			values (
				Mt.EffectiveDate
				,Mt.Exchangerate
				,Mt.No
				);
end
go


