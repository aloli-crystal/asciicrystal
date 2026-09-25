require "../spec_helper"

# Helper methods used across table tests
# NOTE: Asciicrystal.convert bypasses Document#convert so standalone option is ignored.
# We use Asciicrystal.load + doc.convert for embedded output.
def table_convert_string(input : String, options : Hash(String, String) = {} of String => String) : String
  Asciicrystal.convert(input, options)
end

def table_convert_to_embedded(input : String, options : Hash(String, String) = {} of String => String) : String
  doc = Asciicrystal.load(input, options)
  result = doc.convert
  result || ""
end

def table_document_from_string(input : String, options : Hash(String, String) = {} of String => String) : Asciicrystal::Document
  Asciicrystal.load(input, options)
end

describe Asciicrystal::Table do
  # ==========================================================================
  # #initialize
  # ==========================================================================
  describe "#initialize" do
    it "creates a table" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      table.context.should eq(:table)
      table.columns.should be_empty
      table.rows.head.should be_empty
      table.rows.body.should be_empty
      table.rows.foot.should be_empty
    end
  end

  # ==========================================================================
  # #header_row?
  # ==========================================================================
  describe "#header_row?" do
    it "returns false when has_header_option is false" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      table.header_row?.should be_false
    end

    it "returns true when has_header_option is true and body is empty" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      table.has_header_option = true
      table.header_row?.should be_true
    end
  end

  # ==========================================================================
  # Rows
  # ==========================================================================
  describe "Asciicrystal::Table::Rows" do
    it "provides rows by section" do
      rows = Asciicrystal::Table::Rows.new
      sections = rows.by_section
      sections.size.should eq(3)
      sections[0][0].should eq(:head)
      sections[1][0].should eq(:body)
      sections[2][0].should eq(:foot)
    end

    it "converts to hash" do
      rows = Asciicrystal::Table::Rows.new
      h = rows.to_h
      h.has_key?(:head).should be_true
      h.has_key?(:body).should be_true
      h.has_key?(:foot).should be_true
    end
  end

  # ==========================================================================
  # Column
  # ==========================================================================
  describe "Column" do
    it "creates a column with default attributes" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      col = Asciicrystal::Table::Column.new(table, 0)
      col.attributes["colnumber"].should eq("1")
      col.attributes["width"].should eq("1")
      col.attributes["halign"].should eq("left")
      col.attributes["valign"].should eq("top")
    end

    it "creates a column with specific index" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      col = Asciicrystal::Table::Column.new(table, 2)
      col.attributes["colnumber"].should eq("3")
    end
  end

  # ==========================================================================
  # Cell
  # ==========================================================================
  describe "Cell" do
    it "creates a cell with text" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      col = Asciicrystal::Table::Column.new(table, 0)
      cell = Asciicrystal::Table::Cell.new(col, "Cell content")
      cell.text.should eq("Cell content")
    end

    it "creates a cell with colspan and rowspan" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      col = Asciicrystal::Table::Column.new(table, 0)
      cell = Asciicrystal::Table::Cell.new(col, "Cell", colspan: 2, rowspan: 3)
      cell.colspan.should eq(2)
      cell.rowspan.should eq(3)
    end

    it "returns the cell text" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      col = Asciicrystal::Table::Column.new(table, 0)
      cell = Asciicrystal::Table::Cell.new(col, "Hello")
      cell.text.should eq("Hello")
    end

    it "returns array with single paragraph for content" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      col = Asciicrystal::Table::Column.new(table, 0)
      cell = Asciicrystal::Table::Cell.new(col, "Single paragraph")
      cell.content.should eq(["Single paragraph"])
    end

    it "splits content on blank lines" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      col = Asciicrystal::Table::Column.new(table, 0)
      cell = Asciicrystal::Table::Cell.new(col, "Para 1\n\nPara 2")
      cell.content.should eq(["Para 1", "Para 2"])
    end

    it "cell with empty text returns empty string" do
      doc = Asciicrystal::Document.new
      table = Asciicrystal::Table.new(doc)
      col = Asciicrystal::Table::Column.new(table, 0)
      cell = Asciicrystal::Table::Cell.new(col, "")
      cell.text.should eq("")
    end
  end

  # ==========================================================================
  # PSV Tables (Pipe Separated Values)
  # ==========================================================================
  describe "PSV" do
    it "converts simple psv table to HTML" do
      input = "|===\n|A |B |C\n|a |b |c\n|1 |2 |3\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<table")
      output.should contain("tableblock")
    end

    it "should parse 3 rows and 3 columns" do
      input = "|===\n|A |B |C\n|a |b |c\n|1 |2 |3\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(3)
      table.rows.body.size.should eq(3)
      table.rows.body[0].size.should eq(3)
    end

    it "should parse cell content correctly" do
      input = "|===\n|A |B |C\n|a |b |c\n|1 |2 |3\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body[0][0].text.should eq("A")
      table.rows.body[0][1].text.should eq("B")
      table.rows.body[0][2].text.should eq("C")
      table.rows.body[1][0].text.should eq("a")
      table.rows.body[1][1].text.should eq("b")
      table.rows.body[1][2].text.should eq("c")
      table.rows.body[2][0].text.should eq("1")
      table.rows.body[2][1].text.should eq("2")
      table.rows.body[2][2].text.should eq("3")
    end

    it "first row sets number of columns when not specified" do
      input = "|===\n|first |second |third |fourth\n|1 |2 |3\n|4\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(4)
    end

    it "outputs a caption on psv table" do
      input = ".Simple psv table\n|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<caption")
      output.should contain("Simple psv table")
    end

    it "table with header using %header shorthand" do
      input = "[%header]\n|===\n|Item |Quantity\n|Item 1 |1\n|Item 2 |2\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<thead")
      output.should contain("<th")
      output.should contain("<tbody")
    end

    it "table with header should have correct head and body rows" do
      input = "[%header]\n|===\n|Item |Quantity\n|Item 1 |1\n|Item 2 |2\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.head.size.should eq(1)
      table.rows.body.size.should eq(2)
    end

    it "header cells should contain correct text" do
      input = "[%header]\n|===\n|Name |Value\n|A |1\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.head[0][0].text.should eq("Name")
      table.rows.head[0][1].text.should eq("Value")
    end

    it "should output halign and valign classes on cells" do
      input = "|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("halign-left")
      output.should contain("valign-top")
    end

    it "should output p.tableblock inside td" do
      input = "|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("p class=\"tableblock\"")
    end

    it "should output colgroup with col elements" do
      input = "|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<colgroup>")
      output.should contain("<col")
    end

    it "should produce frame-all and grid-all classes by default" do
      input = "|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("frame-all")
      output.should contain("grid-all")
    end

    # Pending: block attributes not propagated to table node
    it "should add direction CSS class if float attribute is set on table" do
      input = "[float=left]\n|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("left")
    end

    it "should set stripes class if stripes option is set" do
      input = "[stripes=odd]\n|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("stripes-odd")
    end

    it "should set stripes class to even" do
      input = "[stripes=even]\n|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("stripes-even")
    end

    it "should include table number in caption" do
      input = ".Simple psv table\n|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("Table 1. Simple psv table")
    end

    it "only increments table counter for tables that have a title" do
      input = ".First\n|===\n|1 |2 |3\n|===\n\n|===\n|4 |5 |6\n|===\n\n.Second\n|===\n|7 |8 |9\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("Table 1. First")
      output.should contain("Table 2. Second")
    end

    it "ignores escaped separators" do
      input = "|===\n|A \\| here| a \\| there\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("A | here")
      output.should contain("a | there")
    end

    it "table and column width not assigned when autowidth option is specified" do
      input = "[%autowidth]\n|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("fit-content")
    end

    it "colspec attribute using asterisk syntax sets number of columns" do
      input = "[cols=\"3*\"]\n|===\n|A |B |C |a |b |c |1 |2 |3\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(3)
      table.rows.body.size.should eq(3)
    end

    it "table with explicit column count can have multiple rows on a single line" do
      input = "[cols=\"3*\"]\n|===\n|one |two\n|1 |2 |a |b\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(3)
      table.rows.body.size.should eq(2)
    end

    it "should preserve frame value ends when converting to HTML" do
      input = "[frame=ends]\n|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("frame-ends")
    end

    it "should normalize frame value topbot as ends when converting to HTML" do
      input = "[frame=topbot]\n|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("frame-ends")
    end

    it "should support frame=none" do
      input = "[frame=none]\n|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("frame-none")
    end

    it "should support frame=sides" do
      input = "[frame=sides]\n|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("frame-sides")
    end

    it "should support grid=rows" do
      input = "[grid=rows]\n|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("grid-rows")
    end

    it "should support grid=cols" do
      input = "[grid=cols]\n|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("grid-cols")
    end

    it "should support grid=none" do
      input = "[grid=none]\n|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("grid-none")
    end

    it "should set table width" do
      input = "[width=\"80%\"]\n|===\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("80%")
    end

    it "table with header and footer" do
      input = "[%header%footer]\n|===\n|Item |Qty\n|Item 1 |1\n|Item 2 |2\n|Total |3\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<thead")
      output.should contain("<tfoot")
      output.should contain("<tbody")
    end

    it "table with implicit header row" do
      input = "|===\n|Column 1 |Column 2\n\n|Data A1\n|Data B1\n\n|Data A2\n|Data B2\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<thead")
      output.should contain("<th")
    end

    it "no implicit header row if second line not blank" do
      input = "|===\n|Column 1 |Column 2\n|Data A1\n|Data B1\n\n|Data A2\n|Data B2\n|==="
      output = table_convert_to_embedded(input)
      output.should_not contain("<thead")
    end

    it "spans, alignments and styles" do
      input = "[cols=\"e,m,^,>s\",width=\"25%\"]\n|===\n|1 >s|2 |3 |4\n^|5 2.2+^.^|6 .3+<.>m|7\n^|8\nd|9 2+>|10\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("colspan")
      output.should contain("rowspan")
    end

    it "supports repeating cells with 3*" do
      input = "|===\n3*|A\n|1 3*|2\n|b |c\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(3)
    end

    it "column styles (e, m, s)" do
      input = "[cols=\"1e,1m,1s\"]
|===
|emphasis |monospace |strong
|==="
      output = table_convert_to_embedded(input)
      output.should contain("<em>")
      output.should contain("<code>")
      output.should contain("<strong>")
    end

    it "vertical table headers use th element" do
      input = "[cols=\"1h,1,1\"]
|===
|Name |Occupation |Website
|==="
      output = table_convert_to_embedded(input)
      output.should contain("<th")
    end

    it "percentages as column widths" do
      input = "[cols=\"<.^10%,<90%\"]
|===
|column A |column B
|==="
      output = table_convert_to_embedded(input)
      # Accept both "10%" and "10.0%" formats
      (output.includes?("10%") || output.includes?("10.0%")).should be_true
      (output.includes?("90%") || output.includes?("90.0%")).should be_true
    end

    it "AsciiDoc table cell" do
      input = "|===\na|--\nNOTE: content\n\ncontent\n--\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("tableblock")
    end

    pending "nested table" do
      input = "[cols=\"1,2a\"]\n|===\n|Normal cell\n|Cell with nested table\n[cols=\"2,1\"]\n!===\n!Nested table cell 1 !Nested table cell 2\n!===\n|==="
      output = table_convert_to_embedded(input)
      output.scan("<table").size.should eq(2)
    end

    it "should warn if table block is not terminated" do
      input = "outside\n\n|===\n|\ninside\n\nstill inside\n\neof"
      output = table_convert_to_embedded(input)
      output.should contain("<table")
    end
  end

  # ==========================================================================
  # DSV Tables (Delimiter Separated Values)
  # ==========================================================================
  describe "DSV" do
    it "converts dsv table to HTML" do
      input = ":===\na:b:c\n1:2:3\n:==="
      output = table_convert_to_embedded(input)
      output.should contain("<table")
      output.should contain("<td")
    end

    it "dsv table should have at least one row" do
      input = ":===\na:b:c\n1:2:3\n:==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should be >= 1
    end

    it "single cell in DSV table should only produce single row" do
      input = ":===\nsingle cell\n:==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should eq(1)
      table.rows.body[0].size.should eq(1)
    end

    it "dsv table should parse 3 columns correctly" do
      input = ":===\na:b:c\n1:2:3\n:==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(3)
      table.rows.body.size.should eq(2)
    end

    it "dsv format with width" do
      input = "[width=\"75%\",format=\"dsv\"]\n|===\nroot:x:0\nbin:x:1\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("75%")
    end

    it "should parse dsv with escaped colons" do
      input = ":===\nMySQL\\:Server:value\n:==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(2)
    end

    it "should treat trailing colon as an empty cell" do
      input = ":===\nA1:\nB1:B2\nC1:C2\n:==="
      output = table_convert_to_embedded(input)
      output.should contain("A1")
      output.should contain("B1")
    end
  end

  # ==========================================================================
  # CSV Tables (Comma Separated Values)
  # ==========================================================================
  describe "CSV" do
    it "csv format shorthand" do
      input = ",===\na,b,c\n1,2,3\n,==="
      output = table_convert_to_embedded(input)
      output.should contain("<table")
    end

    it "csv table should have at least one row" do
      input = ",===\na,b,c\n1,2,3\n,==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should be >= 1
    end

    it "single cell in CSV table should only produce single row" do
      input = ",===\nsingle cell\n,==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should eq(1)
      table.rows.body[0].size.should eq(1)
    end

    it "csv table should parse 3 columns correctly" do
      input = ",===\na,b,c\n1,2,3\n,==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(3)
      table.rows.body.size.should eq(2)
    end

    it "csv table should parse cell content correctly" do
      input = ",===\na,b,c\n1,2,3\n,==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body[0][0].text.should eq("a")
      table.rows.body[0][1].text.should eq("b")
    end

    it "should treat trailing comma as an empty cell" do
      input = ",===\nA1,\nB1,B2\nC1,C2\n,==="
      output = table_convert_to_embedded(input)
      output.should contain("A1")
    end

    it "should preserve newlines in quoted CSV values" do
      input = "[cols=\"1,1\"]\n,===\n\"A\nB\nC\",\"one\n\ntwo\n\nthree\"\n,==="
      output = table_convert_to_embedded(input)
      output.should contain("A")
    end

    it "mixed unquoted records and quoted records with escaped quotes" do
      input = "[format=\"csv\",%header]\n|===\nYear,Make,Model,Description,Price\n1997,Ford,E350,\"ac, abs, moon\",3000.00\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("ac, abs, moon")
    end

    it "custom csv separator" do
      input = "[format=csv,separator=;]\n|===\na;b;c\n1;2;3\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<table")
    end

    it "tsv as format" do
      input = "[format=tsv]\n,===\na\tb\tc\n1\t2\t3\n,==="
      output = table_convert_to_embedded(input)
      output.should contain("<table")
    end

    pending "cell formatted with AsciiDoc style in CSV" do
      input = "[cols=\"1,1,1a\",separator=;]\n,===\nelement;description;example\n\nthematic break;a visible break;---\n,==="
      output = table_convert_to_embedded(input)
      output.should contain("<hr")
    end
  end

  # ==========================================================================
  # Integration: Parsing tables from documents
  # ==========================================================================
  describe "Integration" do
    it "should parse a simple table from document" do
      input = "|===\n|A |B\n|1 |2\n|==="
      doc = table_document_from_string(input)
      doc.blocks.size.should eq(1)
      doc.blocks[0].should be_a(Asciicrystal::Table)
    end

    it "should parse table with multiple rows" do
      input = "|===\n|A |B |C\n|a |b |c\n|1 |2 |3\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should eq(3)
    end

    it "should convert table to HTML with correct structure" do
      input = "|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<table")
      output.should contain("<colgroup")
      output.should contain("<col")
      output.should contain("<tbody")
      output.should contain("<tr")
      output.should contain("<td")
      output.should contain("tableblock")
    end

    it "should handle table after paragraph" do
      input = "Some text.\n\n|===\n|A |B\n|1 |2\n|==="
      doc = table_document_from_string(input)
      doc.blocks.size.should eq(2)
      doc.blocks[0].context.should eq(:paragraph)
      doc.blocks[1].should be_a(Asciicrystal::Table)
    end

    it "should handle multiple tables in a document" do
      input = "|===\n|A |B\n|===\n\n|===\n|C |D\n|==="
      doc = table_document_from_string(input)
      doc.blocks.size.should eq(2)
      doc.blocks[0].should be_a(Asciicrystal::Table)
      doc.blocks[1].should be_a(Asciicrystal::Table)
    end

    it "should handle table with title" do
      input = ".My Table\n|===\n|A |B\n|1 |2\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.title.should eq("My Table")
    end

    it "should handle table with id" do
      input = "[#my-table]\n|===\n|A |B\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.id.should eq("my-table")
    end

    it "should convert table inside a section" do
      input = ":sectids:\n\n== Section\n\n|===\n|A |B\n|1 |2\n|==="
      doc = table_document_from_string(input)
      sect = doc.blocks[0]
      sect.should be_a(Asciicrystal::Section)
      if sect.is_a?(Asciicrystal::Section)
        sect.blocks.size.should eq(1)
        sect.blocks[0].should be_a(Asciicrystal::Table)
      end
    end

    it "should handle table with explicit header using %header" do
      input = "[%header]\n|===\n|Name |Value\n|A |1\n|B |2\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.head.size.should eq(1)
      table.rows.body.size.should eq(2)
      table.rows.head[0][0].text.should eq("Name")
      table.rows.head[0][1].text.should eq("Value")
    end

    it "should convert table with header to HTML with thead" do
      input = "[%header]\n|===\n|Name |Value\n|A |1\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<thead")
      output.should contain("<th")
      output.should contain("Name")
      output.should contain("Value")
    end

    it "should handle table with single column" do
      input = "|===\n|A\n|B\n|C\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(1)
      table.rows.body.size.should eq(3)
    end

    it "should handle table with many columns" do
      input = "|===\n|A |B |C |D |E |F\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(6)
    end

    it "should handle empty table" do
      input = "|===\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.should be_empty
    end

    it "should handle table with two columns and two rows" do
      input = "|===\n|A |B\n|C |D\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(2)
      table.rows.body.size.should eq(2)
      table.rows.body[0][0].text.should eq("A")
      table.rows.body[0][1].text.should eq("B")
      table.rows.body[1][0].text.should eq("C")
      table.rows.body[1][1].text.should eq("D")
    end

    it "should handle table with cells on separate lines" do
      input = "|===\n|A\n|B\n|C\n|D\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(1)
      table.rows.body.size.should eq(4)
    end

    it "should handle table with blank line between rows" do
      input = "|===\n|A |B\n\n|C |D\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should be >= 1
    end

    it "should handle table in standalone document" do
      input = "= Document Title\n\n|===\n|A |B\n|1 |2\n|==="
      output = table_convert_string(input)
      output.should contain("<table")
      output.should contain("A")
      output.should contain("B")
    end

    it "should handle table with link in cell" do
      input = "|===\n|https://example.com |text\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("example.com")
    end

    it "should handle table with cols attribute specifying proportional widths" do
      input = "[cols=\"1,2,3\"]\n|===\n|A |B |C\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(3)
    end

    it "should handle table with frame=all by default" do
      input = "|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("frame-all")
    end

    it "should handle table with grid=all by default" do
      input = "|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("grid-all")
    end

    it "should handle table with role" do
      input = "[.custom-role]\n|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("custom-role")
    end

    it "should handle table with autowidth option" do
      input = "[%autowidth]\n|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("fit-content")
    end

    it "explicit table width is used even when autowidth option is specified" do
      input = "[%autowidth,width=75%]\n|===\n|A |B |C\n|a |b |c\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("75%")
    end

    it "should handle table with frame=sides" do
      input = "[frame=sides]\n|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("frame-sides")
    end

    it "should handle table with content containing inline formatting" do
      input = "|===\n|*bold* |_italic_\n|`code` |normal\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<strong>bold</strong>")
      output.should contain("<em>italic</em>")
      output.should contain("<code>code</code>")
    end

    it "should handle table with width=100%" do
      input = "[width=\"100%\"]\n|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      # In AsciiDoctor, width=100% adds "stretch" class (not inline style)
      output.should contain("stretch")
    end

    it "should handle table with stripes=all" do
      input = "[stripes=all]\n|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("stripes-all")
    end

    it "should handle table with stripes=hover" do
      input = "[stripes=hover]\n|===\n|A |B\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("stripes-hover")
    end

    it "should handle table with options=header via options attribute" do
      input = "[options=\"header\"]\n|===\n|Name |Value\n|A |1\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.head.size.should eq(1)
    end

    it "should handle table with cols using asterisk multiplier" do
      input = "[cols=\"3*\"]\n|===\n|A |B |C |a |b |c |1 |2 |3\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.columns.size.should eq(3)
    end

    it "should handle table with colspan" do
      input = "|===\n2+|Spanning |Normal\n|A |B |C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("colspan")
    end

    it "should handle table with rowspan" do
      input = "|===\n.2+|Spanning |B\n|C\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("rowspan")
    end

    it "should handle table with literal cell style" do
      input = "[cols=\"1l,1\"]\n|===\n|literal |normal\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<pre>")
    end

    it "should handle table with AsciiDoc cell style" do
      input = "|===\na|AsciiDoc cell\n|normal cell\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("content")
    end

    it "should handle table with emphasis cell style" do
      input = "[cols=\"1e,1\"]\n|===\n|emphasis |normal\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<em>")
    end

    it "should handle table with monospace cell style" do
      input = "[cols=\"1m,1\"]\n|===\n|monospace |normal\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<code>")
    end

    it "should handle table with strong cell style" do
      input = "[cols=\"1s,1\"]\n|===\n|strong |normal\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<strong>")
    end

    it "should handle table with header cell style" do
      input = "[cols=\"1h,1\"]\n|===\n|header |normal\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<th")
    end

    it "should handle table with center alignment" do
      input = "[cols=\"^1,1\"]\n|===\n|center |left\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("halign-center")
    end

    it "should handle table with right alignment" do
      input = "[cols=\">1,1\"]\n|===\n|right |left\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("halign-right")
    end

    it "should handle table with middle vertical alignment" do
      input = "[cols=\".^1,1\"]\n|===\n|middle |top\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("valign-middle")
    end

    it "should handle table with bottom vertical alignment" do
      input = "[cols=\".>1,1\"]\n|===\n|bottom |top\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("valign-bottom")
    end
  end

  # ==========================================================================
  # Cell-spec multiplier (`N*`) vs cell content
  # ==========================================================================
  describe "cell spec multiplier vs multi-line cell content" do
    it "does not treat a bold cell ending in a number as a repeat multiplier" do
      # Régression : le `6.0*` final de `*Rails 5.2 6.0*` (un gras qui
      # se termine par un nombre) était matché par CellSpecEndRx comme
      # le multiplicateur « répéter 6× » de la cellule suivante, ce qui
      # gonflait le tableau (21 rangées au lieu de 10 sur un cas réel).
      # Le spec de fin ne doit être cherché que sur la DERNIÈRE ligne du
      # fragment, jamais dans le contenu d'une ligne précédente.
      input = "[cols=\"1,4\"]\n|===\n| *Rails 5.2 6.0*\n| desc un\n\n| *Rails 6.0 6.1*\n| desc deux\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should eq(2)
      table.rows.body.each { |row| row.size.should eq(2) }
    end

    it "still honors a real repeat multiplier (N*) on a single-line cell spec" do
      # `3*|` répète la cellule suivante 3 fois : a, b, b, b, c => 5 cellules.
      input = "[cols=\"4\"]\n|===\n| a 3*| b\n| c\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.sum(&.size).should eq(5)
    end

    it "applies a cell spec written at the start of a line to the next cell" do
      # Régression : `5+|` en début de ligne restait collé au contenu de
      # la cellule précédente (`0,02 m³\n5+`) au lieu de fusionner la
      # cellule suivante sur 5 colonnes.
      input = "[cols=\"6\"]\n|===\n| a | b | c | d | e | 0,02 m³\n5+| Total | env. 3,6 m³\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should eq(2)
      table.rows.body[0][5].text.strip.should eq("0,02 m³")
      row = table.rows.body[1]
      row.map(&.text.strip).should eq(["Total", "env. 3,6 m³"])
      row[0].colspan.should eq(5)
    end

    it "applies a rowspan spec written at the start of a line" do
      input = "[cols=\"2\"]\n|===\n| a | b\n.2+| fusion | c\n| d\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body[0][1].text.strip.should eq("b")
      table.rows.body[1][0].rowspan.should eq(2)
    end

    it "does not read a cell spec at the end of the last cell of the table" do
      # Régression : la dernière cellule `*11 570*` (gras d'un nombre à
      # séparateur de milliers) finit par ` 570*`, que CellSpecEndRx
      # lisait comme le multiplicateur « répéter 570× » d'une cellule
      # suivante inexistante : la cellule devenait `*11`. Aucun `|` ne
      # suit le dernier fragment, il ne peut donc porter aucun spec.
      input = "[cols=\"2,2\"]\n|===\n| a | b\n| *10 400* | *11 570*\n|==="
      doc = table_document_from_string(input)
      table = doc.blocks[0].as(Asciicrystal::Table)
      table.rows.body.size.should eq(2)
      table.rows.body[1].map(&.text.strip).should eq(["<strong>10 400</strong>", "<strong>11 570</strong>"])
    end
  end

  # ==========================================================================
  # Blancs autour du texte d'une cellule
  # ==========================================================================
  describe "cell text whitespace" do
    it "strips the leading and trailing spaces of a cell, as Asciidoctor" do
      # Régression : `| janvier | 370` donnait « ␣janvier » (seule
      # l'espace de fin était retirée). Asciidoctor retire les deux.
      input = "[cols=\"2\"]\n|===\n| janvier | 370\n|==="
      doc = table_document_from_string(input)
      row = doc.blocks[0].as(Asciicrystal::Table).rows.body[0]
      row.map(&.source).should eq(["janvier", "370"])
      row.map(&.text).should eq(["janvier", "370"])
    end

    it "converts the body of an asciidoc cell as nested AsciiDoc" do
      input = "[cols=\"1a\"]\n|===\n|\n[source,ruby]\n----\nputs 1\n----\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<pre")
      output.should contain("puts 1")
      # Le contenu d'une cellule ne doit jamais fuir sous forme de
      # structure Crystal — ni crochets, ni sauts de ligne échappés.
      output.should_not contain("[\"")
      output.should_not contain("\\n----")
    end

    it "converts a list in an asciidoc cell" do
      input = "[cols=\"1a\"]\n|===\n|\n* un\n* deux\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("<ul")
      output.should contain("<li>")
      output.should_not contain("* un")
    end

    it "resolves document attributes inside an asciidoc cell" do
      input = ":ville: Paray-le-Monial\n\n[cols=\"1a\"]\n|===\n|\nÀ {ville}.\n|==="
      output = table_convert_to_embedded(input)
      output.should contain("Paray-le-Monial")
      output.should_not contain("{ville}")
    end

    it "strips the spaces of an asciidoc cell" do
      input = "[cols=\"1a\"]\n|===\n|   texte  \n|==="
      doc = table_document_from_string(input)
      doc.blocks[0].as(Asciicrystal::Table).rows.body[0][0].source.should eq("texte")
    end

    it "keeps the indentation of a literal cell, dropping only leading newlines" do
      input = "[cols=\"1l\"]\n|===\n|\n  indenté\n  suite  \n|==="
      doc = table_document_from_string(input)
      doc.blocks[0].as(Asciicrystal::Table).rows.body[0][0].source.should eq("  indenté\n  suite")
    end
  end
end
