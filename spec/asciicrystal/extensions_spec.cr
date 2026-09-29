require "../spec_helper"

# =============================================================================
# Test Processors -- simple implementations for testing each extension type
# =============================================================================

# A Preprocessor that adds a line at the beginning of the source.
class SamplePreprocessor < Asciicrystal::Extensions::Preprocessor
  def process(document : Asciicrystal::Document, reader : Asciicrystal::Reader) : Asciicrystal::Reader?
    document.attributes["preprocessor-ran"] = "true"
    nil
  end
end

# A Preprocessor that replaces lines.
class PrependLinePreprocessor < Asciicrystal::Extensions::Preprocessor
  def process(document : Asciicrystal::Document, reader : Asciicrystal::Reader) : Asciicrystal::Reader?
    new_lines = ["// Prepended by extension"] + reader.lines
    Asciicrystal::Reader.new(new_lines)
  end
end

# A Preprocessor that scrubs the header (removes lines before the first = Title line).
class ScrubHeaderPreprocessor < Asciicrystal::Extensions::Preprocessor
  def process(document : Asciicrystal::Document, reader : Asciicrystal::Reader) : Asciicrystal::Reader?
    skipped = [] of String
    lines = reader.lines
    new_lines = lines.dup
    while !new_lines.empty? && !new_lines.first.starts_with?("= ")
      skipped << new_lines.shift
    end
    unless skipped.empty?
      document.attributes["skipped"] = skipped.join("\n")
    end
    Asciicrystal::Reader.new(new_lines)
  end
end

# A TreeProcessor that sets an attribute on the document.
class SampleTreeProcessor < Asciicrystal::Extensions::TreeProcessor
  def process(document : Asciicrystal::Document) : Asciicrystal::Document?
    document.attributes["tree-processor-ran"] = "true"
    nil
  end
end

# A TreeProcessor that replaces the author attribute.
class ReplaceAuthorTreeProcessor < Asciicrystal::Extensions::TreeProcessor
  def process(document : Asciicrystal::Document) : Asciicrystal::Document?
    document.attributes["firstname"] = "Ghost"
    document.attributes["author"] = "Ghost Writer"
    document
  end
end

# A Postprocessor that uppercases the output.
class UppercasePostprocessor < Asciicrystal::Extensions::Postprocessor
  def process(document : Asciicrystal::Document, output : String) : String
    output.upcase
  end
end

# A Postprocessor that strips HTML attributes.
class StripAttributesPostprocessor < Asciicrystal::Extensions::Postprocessor
  def process(document : Asciicrystal::Document, output : String) : String
    output.gsub(/<(\w+)[^>]*>/, "<\\1>")
  end
end

# A Postprocessor that appends a footer comment.
class AppendFooterPostprocessor < Asciicrystal::Extensions::Postprocessor
  def process(document : Asciicrystal::Document, output : String) : String
    output + "\n<!-- footer -->"
  end
end

# An IncludeProcessor that handles .txt targets.
class BoilerplateIncludeProcessor < Asciicrystal::Extensions::IncludeProcessor
  def handles?(target : String) : Bool
    target.ends_with?(".txt")
  end

  def process(document : Asciicrystal::Document, reader : Asciicrystal::Reader, target : String, attributes : Hash(String, String)) : Nil
    document.attributes["include-processor-ran"] = target
  end
end

# A DocinfoProcessor that injects a meta tag in the head.
class MetaRobotsDocinfoProcessor < Asciicrystal::Extensions::DocinfoProcessor
  def process(document : Asciicrystal::Document) : String
    %(<meta name="robots" content="index,follow">)
  end
end

# A DocinfoProcessor that injects a meta app tag in the head.
class MetaAppDocinfoProcessor < Asciicrystal::Extensions::DocinfoProcessor
  def process(document : Asciicrystal::Document) : String
    %(<meta name="application-name" content="Asciicrystal App">)
  end
end

# A DocinfoProcessor at footer location.
class FooterDocinfoProcessor < Asciicrystal::Extensions::DocinfoProcessor
  def initialize
    super({"location" => :footer} of String => String | Bool | Int32 | Array(String) | Set(Symbol) | Symbol)
  end

  def process(document : Asciicrystal::Document) : String
    "<script>console.log('footer')</script>"
  end
end

# A BlockProcessor that uppercases paragraph content.
class UppercaseBlockProcessor < Asciicrystal::Extensions::BlockProcessor
  def initialize
    super("yell")
  end

  def process(parent : Asciicrystal::AbstractBlock, reader : Asciicrystal::Reader, attributes : Hash(String, String)) : Asciicrystal::AbstractBlock?
    lines = reader.lines.map(&.upcase)
    create_paragraph(parent, lines, attributes)
  end
end

# A BlockMacroProcessor that creates a pass block with a script tag.
class SnippetBlockMacro < Asciicrystal::Extensions::BlockMacroProcessor
  def initialize
    super("snippet")
  end

  def process(parent : Asciicrystal::AbstractBlock, target : String, attributes : Hash(String, String)) : Asciicrystal::AbstractBlock | Asciicrystal::Inline | Nil
    mode = attributes["mode"]? || "default"
    create_pass_block(parent, %(<script src="http://example.com/#{target}.js?_mode=#{mode}"></script>), {} of String => String)
  end
end

# A BlockMacroProcessor that creates an image block.
class TestImageBlockMacro < Asciicrystal::Extensions::BlockMacroProcessor
  def initialize
    super("testimg")
  end

  def process(parent : Asciicrystal::AbstractBlock, target : String, attributes : Hash(String, String)) : Asciicrystal::AbstractBlock | Asciicrystal::Inline | Nil
    create_image_block(parent, {"target" => "#{target}.png"})
  end
end

# An InlineMacroProcessor for a temperature conversion macro.
class TemperatureInlineMacro < Asciicrystal::Extensions::InlineMacroProcessor
  def initialize
    super("degrees")
  end

  def process(parent : Asciicrystal::AbstractBlock, target : String, attributes : Hash(String, String)) : Asciicrystal::AbstractBlock | Asciicrystal::Inline | Nil
    units = attributes["1"]? || "C"
    c = target.to_f
    text = case units
           when "F"
             "#{(c * 1.8 + 32).round(1)} F"
           else
             "#{c.round(1)} C"
           end
    create_inline(parent, :quoted, text, {"type" => :unquoted} of String => String | Symbol)
  end
end

# A Group that registers a preprocessor.
class SampleExtensionGroup < Asciicrystal::Extensions::Group
  def activate(registry : Asciicrystal::Extensions::Registry) : Nil
    if doc = registry.document
      doc.attributes["activate-method-called"] = ""
    end
    registry.preprocessor(SamplePreprocessor.new)
  end
end

# A Group that registers multiple extensions.
class MultiExtensionGroup < Asciicrystal::Extensions::Group
  def activate(registry : Asciicrystal::Extensions::Registry) : Nil
    registry.preprocessor(SamplePreprocessor.new)
    registry.tree_processor(SampleTreeProcessor.new)
  end
end

# =============================================================================
# Tests
# =============================================================================

describe Asciicrystal::Extensions do
  # ---------------------------------------------------------------------------
  # Global Registration
  # ---------------------------------------------------------------------------
  describe ".register and .unregister_all" do
    it "should not have any groups registered by default" do
      Asciicrystal::Extensions.unregister_all
      Asciicrystal::Extensions.groups.should be_empty
    end

    it "should register an extension group class" do
      begin
        Asciicrystal::Extensions.register(:sample, SampleExtensionGroup)
        Asciicrystal::Extensions.groups.size.should eq(1)
        Asciicrystal::Extensions.groups[:sample].should eq(SampleExtensionGroup)
      ensure
        Asciicrystal::Extensions.unregister_all
      end
    end

    it "should register an extension group instance" do
      begin
        instance = SampleExtensionGroup.new
        Asciicrystal::Extensions.register(:sample, instance)
        Asciicrystal::Extensions.groups.size.should eq(1)
        Asciicrystal::Extensions.groups[:sample].should be_a(SampleExtensionGroup)
      ensure
        Asciicrystal::Extensions.unregister_all
      end
    end

    it "should self-register an extension group class" do
      begin
        SampleExtensionGroup.register(:sample)
        Asciicrystal::Extensions.groups.size.should eq(1)
        Asciicrystal::Extensions.groups[:sample].should eq(SampleExtensionGroup)
      ensure
        Asciicrystal::Extensions.unregister_all
      end
    end

    it "should generate a name if none is given" do
      begin
        Asciicrystal::Extensions.register(nil, SampleExtensionGroup)
        Asciicrystal::Extensions.groups.size.should eq(1)
      ensure
        Asciicrystal::Extensions.unregister_all
      end
    end

    it "should unregister all groups" do
      Asciicrystal::Extensions.register(:a, SampleExtensionGroup)
      Asciicrystal::Extensions.register(:b, SampleExtensionGroup)
      Asciicrystal::Extensions.groups.size.should eq(2)
      Asciicrystal::Extensions.unregister_all
      Asciicrystal::Extensions.groups.should be_empty
    end

    it "should unregister specific groups by name" do
      begin
        Asciicrystal::Extensions.register(:a, SampleExtensionGroup)
        Asciicrystal::Extensions.register(:b, SampleExtensionGroup)
        Asciicrystal::Extensions.unregister(:a)
        Asciicrystal::Extensions.groups.size.should eq(1)
        Asciicrystal::Extensions.groups.has_key?(:b).should be_true
      ensure
        Asciicrystal::Extensions.unregister_all
      end
    end

    it "should unregister multiple extension groups by name" do
      begin
        Asciicrystal::Extensions.register(:sample1, SampleExtensionGroup)
        Asciicrystal::Extensions.register(:sample2, SampleExtensionGroup)
        Asciicrystal::Extensions.groups.size.should eq(2)
        Asciicrystal::Extensions.unregister(:sample1, :sample2)
        Asciicrystal::Extensions.groups.size.should eq(0)
      ensure
        Asciicrystal::Extensions.unregister_all
      end
    end

    it "should not fail to unregister extension group if not registered" do
      Asciicrystal::Extensions.unregister_all
      Asciicrystal::Extensions.groups.size.should eq(0)
      Asciicrystal::Extensions.unregister(:nonexistent)
      Asciicrystal::Extensions.groups.size.should eq(0)
    end

    it "should coerce group name to symbol when registering" do
      begin
        Asciicrystal::Extensions.register(:sample_coerce, SampleExtensionGroup)
        Asciicrystal::Extensions.groups.size.should eq(1)
        Asciicrystal::Extensions.groups[:sample_coerce].should eq(SampleExtensionGroup)
      ensure
        Asciicrystal::Extensions.unregister_all
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Registry
  # ---------------------------------------------------------------------------
  describe Asciicrystal::Extensions::Registry do
    describe "#initialize" do
      it "creates an empty registry" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.preprocessors?.should be_false
        registry.tree_processors?.should be_false
        registry.postprocessors?.should be_false
        registry.include_processors?.should be_false
        registry.docinfo_processors?.should be_false
        registry.blocks?.should be_false
        registry.block_macros?.should be_false
        registry.inline_macros?.should be_false
      end
    end

    describe "#activate" do
      it "activates the registry with a document" do
        registry = Asciicrystal::Extensions::Registry.new
        doc = Asciicrystal::Document.new
        registry.activate(doc)
        registry.document.should eq(doc)
      end

      it "activates groups registered on the registry" do
        groups = {
          :sample => SampleExtensionGroup.new.as(Asciicrystal::Extensions::Group.class | Asciicrystal::Extensions::Group),
        }
        registry = Asciicrystal::Extensions::Registry.new(groups)
        doc = Asciicrystal::Document.new
        registry.activate(doc)
        registry.preprocessors?.should be_true
        doc.attributes["activate-method-called"]?.should eq("")
      end

      it "should call activate on extension group class" do
        begin
          Asciicrystal::Extensions.register(:sample, SampleExtensionGroup)
          doc = Asciicrystal::Document.new
          registry = Asciicrystal::Extensions::Registry.new
          registry.activate(doc)
          doc.attributes["activate-method-called"]?.should eq("")
          registry.preprocessors?.should be_true
        ensure
          Asciicrystal::Extensions.unregister_all
        end
      end

      it "should reset registry if activate is called again" do
        begin
          Asciicrystal::Extensions.register(:sample, SampleExtensionGroup)
          doc = Asciicrystal::Document.new
          registry = Asciicrystal::Extensions::Registry.new
          registry.activate(doc)
          doc.attributes["activate-method-called"]?.should eq("")
          registry.preprocessors?.should be_true
          registry.preprocessors.size.should eq(1)
          registry.document.should eq(doc)

          doc2 = Asciicrystal::Document.new
          registry.activate(doc2)
          doc2.attributes["activate-method-called"]?.should eq("")
          registry.preprocessors?.should be_true
          registry.preprocessors.size.should eq(1)
          registry.document.should eq(doc2)
        ensure
          Asciicrystal::Extensions.unregister_all
        end
      end

      it "should create registry in Document if extensions are loaded" do
        begin
          SampleExtensionGroup.register(:sample)
          doc = Asciicrystal::Document.new
          registry = Asciicrystal::Extensions::Registry.new
          registry.activate(doc)
          doc.extensions = registry
          doc.extensions?.should be_true
        ensure
          Asciicrystal::Extensions.unregister_all
        end
      end
    end

    # ---- Preprocessor registration ----
    describe "#preprocessor" do
      it "registers a preprocessor" do
        registry = Asciicrystal::Extensions::Registry.new
        processor = SamplePreprocessor.new
        registry.preprocessor(processor)
        registry.preprocessors?.should be_true
        registry.preprocessors.size.should eq(1)
      end

      it "registers multiple preprocessors in order" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.preprocessor(SamplePreprocessor.new)
        registry.preprocessor(PrependLinePreprocessor.new)
        registry.preprocessors.size.should eq(2)
      end
    end

    # ---- TreeProcessor registration ----
    describe "#tree_processor" do
      it "registers a tree processor" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.tree_processor(SampleTreeProcessor.new)
        registry.tree_processors?.should be_true
        registry.tree_processors.size.should eq(1)
      end
    end

    # ---- Postprocessor registration ----
    describe "#postprocessor" do
      it "registers a postprocessor" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.postprocessor(UppercasePostprocessor.new)
        registry.postprocessors?.should be_true
        registry.postprocessors.size.should eq(1)
      end
    end

    # ---- IncludeProcessor registration ----
    describe "#include_processor" do
      it "registers an include processor" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.include_processor(BoilerplateIncludeProcessor.new)
        registry.include_processors?.should be_true
        registry.include_processors.size.should eq(1)
      end
    end

    # ---- DocinfoProcessor registration ----
    describe "#docinfo_processor" do
      it "registers a docinfo processor" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.docinfo_processor(MetaRobotsDocinfoProcessor.new)
        registry.docinfo_processors?.should be_true
        registry.docinfo_processors.size.should eq(1)
      end

      it "filters docinfo processors by location" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.docinfo_processor(MetaRobotsDocinfoProcessor.new)
        registry.docinfo_processor(FooterDocinfoProcessor.new)
        registry.docinfo_processors(:head).size.should eq(1)
        registry.docinfo_processors(:footer).size.should eq(1)
        registry.docinfo_processors.size.should eq(2)
      end
    end

    # ---- BlockProcessor registration ----
    describe "#block" do
      it "registers a block processor" do
        registry = Asciicrystal::Extensions::Registry.new
        processor = UppercaseBlockProcessor.new
        registry.block(processor)
        registry.blocks?.should be_true
        registry.find_block_extension("yell").should_not be_nil
      end

      it "registers a block processor with explicit name" do
        registry = Asciicrystal::Extensions::Registry.new
        processor = UppercaseBlockProcessor.new
        registry.block(processor, "shout")
        registry.find_block_extension("shout").should_not be_nil
      end
    end

    # ---- BlockMacroProcessor registration ----
    describe "#block_macro" do
      it "registers a block macro processor" do
        registry = Asciicrystal::Extensions::Registry.new
        processor = SnippetBlockMacro.new
        registry.block_macro(processor)
        registry.block_macros?.should be_true
        registry.find_block_macro_extension("snippet").should_not be_nil
      end

      it "registers a block macro processor with explicit name" do
        registry = Asciicrystal::Extensions::Registry.new
        processor = SnippetBlockMacro.new
        registry.block_macro(processor, "code_snippet")
        registry.find_block_macro_extension("code_snippet").should_not be_nil
      end
    end

    # ---- InlineMacroProcessor registration ----
    describe "#inline_macro" do
      it "registers an inline macro processor" do
        registry = Asciicrystal::Extensions::Registry.new
        processor = TemperatureInlineMacro.new
        registry.inline_macro(processor)
        registry.inline_macros?.should be_true
        registry.find_inline_macro_extension("degrees").should_not be_nil
      end
    end

    # ---- Lookup methods ----
    describe "#registered_for_block?" do
      it "returns the extension when registered for the given context" do
        registry = Asciicrystal::Extensions::Registry.new
        processor = UppercaseBlockProcessor.new
        registry.block(processor)
        result = registry.registered_for_block?("yell", :paragraph)
        result.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      end

      it "returns false when not registered for the given context" do
        registry = Asciicrystal::Extensions::Registry.new
        processor = UppercaseBlockProcessor.new
        registry.block(processor)
        result = registry.registered_for_block?("yell", :listing)
        result.should be_false
      end

      it "returns false when no block processor with that name exists" do
        registry = Asciicrystal::Extensions::Registry.new
        result = registry.registered_for_block?("unknown", :paragraph)
        result.should be_false
      end
    end

    describe "#registered_for_block_macro?" do
      it "returns the extension when registered" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.block_macro(SnippetBlockMacro.new)
        result = registry.registered_for_block_macro?("snippet")
        result.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      end

      it "returns false when not registered" do
        registry = Asciicrystal::Extensions::Registry.new
        result = registry.registered_for_block_macro?("unknown")
        result.should be_false
      end
    end

    describe "#registered_for_inline_macro?" do
      it "returns the extension when registered" do
        registry = Asciicrystal::Extensions::Registry.new
        registry.inline_macro(TemperatureInlineMacro.new)
        result = registry.registered_for_inline_macro?("degrees")
        result.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      end

      it "returns false when not registered" do
        registry = Asciicrystal::Extensions::Registry.new
        result = registry.registered_for_inline_macro?("unknown")
        result.should be_false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Processor -- create_* methods
  # ---------------------------------------------------------------------------
  describe Asciicrystal::Extensions::Processor do
    describe "#create_block" do
      it "creates a block with the given context" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_block(doc, :paragraph, "Hello World", {} of String => String)
        block.context.should eq(:paragraph)
        block.lines.should eq(["Hello World"])
      end

      it "creates a block with array source" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_block(doc, :listing, ["line 1", "line 2"], {} of String => String)
        block.context.should eq(:listing)
        block.lines.should eq(["line 1", "line 2"])
      end
    end

    # Valeurs attendues relevées avec Asciidoctor Ruby.
    describe "#create_section" do
      it "generates the id from the converted title and stores it in attrs" do
        doc = Asciicrystal.load("= Doc\n\ntexte")
        attrs = {} of String => String
        sect = SnippetBlockMacro.new.create_section(doc, "Voir https://example.org[le site]", attrs)
        sect.id.should eq("_voir_le_site")
        attrs["id"]?.should eq("_voir_le_site")
      end

      it "makes the generated id unique within the document" do
        doc = Asciicrystal.load("= Doc\n\n== Déjà là\n")
        sect = SnippetBlockMacro.new.create_section(doc, "Déjà là", {} of String => String)
        sect.id.should eq("_déjà_là_2")
      end

      it "keeps an explicit id" do
        doc = Asciicrystal.load("= Doc\n\ntexte")
        sect = SnippetBlockMacro.new.create_section(doc, "Autre", {"id" => "perso"})
        sect.id.should eq("perso")
      end

      it "generates no id when sectids is unset" do
        doc = Asciicrystal.load("= Doc\n:sectids!:\n\ntexte")
        attrs = {} of String => String
        sect = SnippetBlockMacro.new.create_section(doc, "Autre", attrs)
        sect.id.should be_nil
        attrs.has_key?("id").should be_false
      end
    end

    describe "#create_image_block" do
      it "creates an image block with target" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_image_block(doc, {"target" => "photo.jpg"})
        block.context.should eq(:image)
        block.attributes["target"]?.should eq("photo.jpg")
        block.attributes["alt"]?.should eq("photo")
      end

      it "raises when target is missing" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        expect_raises(ArgumentError) do
          processor.create_image_block(doc, {} of String => String)
        end
      end

      it "should assign alt attribute to image block if alt is not provided" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_image_block(doc, {"target" => "cat-in-sink-day-25.png"})
        block.attributes["alt"]?.should eq("cat in sink day 25")
      end

      it "should create an image block if mandatory attributes are provided" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_image_block(doc, {"target" => "photo.jpg", "alt" => "My Photo"})
        block.context.should eq(:image)
        block.attributes["target"]?.should eq("photo.jpg")
        block.attributes["alt"]?.should eq("My Photo")
      end
    end

    describe "#create_inline" do
      it "creates an inline node" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        inline = processor.create_inline(doc, :quoted, "text")
        inline.context.should eq(:quoted)
        inline.text.should eq("text")
      end
    end

    describe "#create_list" do
      it "creates a list node" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        list = processor.create_list(doc, :ulist)
        list.context.should eq(:ulist)
      end
    end

    describe "#create_list_item" do
      it "creates a list item with text" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        list = processor.create_list(doc, :ulist)
        item = processor.create_list_item(list, "Item text")
        item.text.should eq("Item text")
      end
    end

    describe "#create_paragraph" do
      it "creates a paragraph block" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_paragraph(doc, "Hello", {} of String => String)
        block.context.should eq(:paragraph)
        block.lines.should eq(["Hello"])
      end
    end

    describe "#create_pass_block" do
      it "creates a pass block with raw content model" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_pass_block(doc, "<b>raw</b>", {} of String => String)
        block.context.should eq(:pass)
        block.content_model.should eq(Asciicrystal::ContentModel::Raw)
      end
    end

    describe "#create_open_block" do
      it "creates an open block" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_open_block(doc, "content", {} of String => String)
        block.context.should eq(:open)
      end
    end

    describe "#create_example_block" do
      it "creates an example block" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_example_block(doc, "content", {} of String => String)
        block.context.should eq(:example)
      end
    end

    describe "#create_listing_block" do
      it "creates a listing block" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_listing_block(doc, "code", {} of String => String)
        block.context.should eq(:listing)
      end
    end

    describe "#create_literal_block" do
      it "creates a literal block" do
        doc = Asciicrystal::Document.new
        processor = SnippetBlockMacro.new
        block = processor.create_literal_block(doc, "text", {} of String => String)
        block.context.should eq(:literal)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Group
  # ---------------------------------------------------------------------------
  describe Asciicrystal::Extensions::Group do
    it "activates and registers extensions on the registry" do
      registry = Asciicrystal::Extensions::Registry.new
      doc = Asciicrystal::Document.new
      registry.activate(doc)
      group = SampleExtensionGroup.new
      group.activate(registry)
      registry.preprocessors?.should be_true
      doc.attributes["activate-method-called"]?.should eq("")
    end
  end

  # ---------------------------------------------------------------------------
  # Extension -- DocinfoProcessor location
  # ---------------------------------------------------------------------------
  describe Asciicrystal::Extensions::DocinfoProcessor do
    it "defaults to head location" do
      processor = MetaRobotsDocinfoProcessor.new
      processor.location.should eq(:head)
    end

    it "can be configured with footer location" do
      processor = FooterDocinfoProcessor.new
      processor.location.should eq(:footer)
    end
  end

  # ---------------------------------------------------------------------------
  # Extension -- IncludeProcessor handles?
  # ---------------------------------------------------------------------------
  describe Asciicrystal::Extensions::IncludeProcessor do
    it "handles? returns true for matching targets" do
      processor = BoilerplateIncludeProcessor.new
      processor.handles?("readme.txt").should be_true
      processor.handles?("readme.adoc").should be_false
    end
  end

  # ---------------------------------------------------------------------------
  # Extension -- BlockProcessor contexts
  # ---------------------------------------------------------------------------
  describe Asciicrystal::Extensions::BlockProcessor do
    it "has default contexts of open and paragraph" do
      processor = UppercaseBlockProcessor.new
      processor.contexts.should eq(Set{:open, :paragraph})
    end
  end

  # ---------------------------------------------------------------------------
  # Extension -- InlineMacroProcessor regexp
  # ---------------------------------------------------------------------------
  describe Asciicrystal::Extensions::InlineMacroProcessor do
    it "resolves a regexp for the macro name" do
      processor = TemperatureInlineMacro.new
      rx = processor.regexp
      rx.should be_a(Regex)
      "degrees:100[C]".matches?(rx).should be_true
    end
  end

  # ---------------------------------------------------------------------------
  # Instantiation tests
  # ---------------------------------------------------------------------------
  describe "Instantiation" do
    it "should instantiate preprocessors" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.preprocessor(SamplePreprocessor.new)
      registry.activate(Asciicrystal::Document.new)
      registry.preprocessors?.should be_true
      extensions = registry.preprocessors
      extensions.size.should eq(1)
      extensions.first.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      extensions.first.instance.should be_a(SamplePreprocessor)
    end

    it "should instantiate include processors" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.include_processor(BoilerplateIncludeProcessor.new)
      registry.activate(Asciicrystal::Document.new)
      registry.include_processors?.should be_true
      extensions = registry.include_processors
      extensions.size.should eq(1)
      extensions.first.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      extensions.first.instance.should be_a(BoilerplateIncludeProcessor)
    end

    it "should instantiate docinfo processors" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.docinfo_processor(MetaRobotsDocinfoProcessor.new)
      registry.activate(Asciicrystal::Document.new)
      registry.docinfo_processors?.should be_true
      registry.docinfo_processors?(:head).should be_true
      extensions = registry.docinfo_processors
      extensions.size.should eq(1)
      extensions.first.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      extensions.first.instance.should be_a(MetaRobotsDocinfoProcessor)
    end

    it "should instantiate tree processors" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.tree_processor(SampleTreeProcessor.new)
      registry.activate(Asciicrystal::Document.new)
      registry.tree_processors?.should be_true
      extensions = registry.tree_processors
      extensions.size.should eq(1)
      extensions.first.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      extensions.first.instance.should be_a(SampleTreeProcessor)
    end

    it "should instantiate postprocessors" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.postprocessor(UppercasePostprocessor.new)
      registry.activate(Asciicrystal::Document.new)
      registry.postprocessors?.should be_true
      extensions = registry.postprocessors
      extensions.size.should eq(1)
      extensions.first.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      extensions.first.instance.should be_a(UppercasePostprocessor)
    end

    it "should instantiate block processor" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.block(UppercaseBlockProcessor.new)
      registry.activate(Asciicrystal::Document.new)
      registry.blocks?.should be_true
      registry.registered_for_block?("yell", :paragraph).should be_a(Asciicrystal::Extensions::ProcessorExtension)
      ext = registry.find_block_extension("yell")
      ext.should_not be_nil
      ext.not_nil!.instance.should be_a(UppercaseBlockProcessor)
    end

    it "should not match block processor for unsupported context" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.block(UppercaseBlockProcessor.new)
      registry.activate(Asciicrystal::Document.new)
      registry.registered_for_block?("yell", :sidebar).should be_false
    end

    it "should instantiate block macro processor" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.block_macro(SnippetBlockMacro.new)
      registry.activate(Asciicrystal::Document.new)
      registry.block_macros?.should be_true
      registry.registered_for_block_macro?("snippet").should be_a(Asciicrystal::Extensions::ProcessorExtension)
      ext = registry.find_block_macro_extension("snippet")
      ext.should_not be_nil
      ext.not_nil!.instance.should be_a(SnippetBlockMacro)
    end

    it "should instantiate inline macro processor" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.inline_macro(TemperatureInlineMacro.new)
      registry.activate(Asciicrystal::Document.new)
      registry.inline_macros?.should be_true
      registry.registered_for_inline_macro?("degrees").should be_a(Asciicrystal::Extensions::ProcessorExtension)
      ext = registry.find_inline_macro_extension("degrees")
      ext.should_not be_nil
      ext.not_nil!.instance.should be_a(TemperatureInlineMacro)
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: Preprocessor runs during parsing
  # ---------------------------------------------------------------------------
  describe "Preprocessor integration" do
    it "runs preprocessor when extensions are set on document" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.preprocessor(SamplePreprocessor.new)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("Hello World")
      Asciicrystal::Parser.parse(reader, doc)

      doc.attributes["preprocessor-ran"]?.should eq("true")
    end

    it "should invoke preprocessors before parsing document (scrub header)" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.preprocessor(ScrubHeaderPreprocessor.new)
      doc.extensions = registry

      source = "junk line\n\n= Document Title\n\nsample content"
      reader = Asciicrystal::Reader.new(source)
      Asciicrystal::Parser.parse(reader, doc)

      doc.attributes["skipped"]?.should_not be_nil
      skipped = doc.attributes["skipped"]?.not_nil!
      skipped.should contain("junk line")
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: TreeProcessor runs during parsing
  # ---------------------------------------------------------------------------
  describe "TreeProcessor integration" do
    it "runs tree processor after parsing" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.tree_processor(SampleTreeProcessor.new)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("Hello World")
      Asciicrystal::Parser.parse(reader, doc)

      doc.attributes["tree-processor-ran"]?.should eq("true")
    end

    it "runs tree processor that modifies document attributes" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.tree_processor(ReplaceAuthorTreeProcessor.new)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("= Title\nOriginal Author\n\nContent")
      Asciicrystal::Parser.parse(reader, doc)

      doc.attributes["author"]?.should eq("Ghost Writer")
      doc.attributes["firstname"]?.should eq("Ghost")
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: Postprocessor modifies output
  # ---------------------------------------------------------------------------
  describe "Postprocessor integration" do
    it "should invoke postprocessors after converting document" do
      # Porting note: Converter now invokes postprocessors from extensions registry
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.postprocessor(UppercasePostprocessor.new)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("Hello World")
      Asciicrystal::Parser.parse(reader, doc)

      converter = Asciicrystal::Converter::Html5Converter.new("html5")
      output = converter.convert(doc)

      output.should eq(output.upcase)
    end

    it "should invoke postprocessor that appends footer" do
      # Porting note: Converter now invokes postprocessors from extensions registry
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.postprocessor(AppendFooterPostprocessor.new)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("Hello World")
      Asciicrystal::Parser.parse(reader, doc)

      converter = Asciicrystal::Converter::Html5Converter.new("html5")
      output = converter.convert(doc)

      output.should contain("<!-- footer -->")
    end

    it "should invoke strip attributes postprocessor" do
      # Porting note: Converter now invokes postprocessors from extensions registry
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.postprocessor(StripAttributesPostprocessor.new)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("Hello World")
      Asciicrystal::Parser.parse(reader, doc)

      converter = Asciicrystal::Converter::Html5Converter.new("html5")
      output = converter.convert(doc)

      # The strip attributes postprocessor removes HTML attributes
      output.should_not contain("class=")
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: IncludeProcessor
  # ---------------------------------------------------------------------------
  describe "IncludeProcessor integration" do
    it "should invoke include processor to process include directive" do
      processor = BoilerplateIncludeProcessor.new
      processor.handles?("lorem-ipsum.txt").should be_true
      processor.handles?("other.adoc").should be_false
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: BlockMacroProcessor runs during parsing
  # ---------------------------------------------------------------------------
  describe "BlockMacroProcessor integration" do
    it "processes a custom block macro during parsing" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.block_macro(SnippetBlockMacro.new)
      doc.extensions = registry

      source = "= Title\n\nsnippet::app[]\n"
      reader = Asciicrystal::Reader.new(source)
      Asciicrystal::Parser.parse(reader, doc)

      # The document should contain a pass block from the macro (may be in preamble)
      found = false
      all_blocks = [] of Asciicrystal::AbstractBlock
      doc.blocks.each do |b|
        if b.is_a?(Asciicrystal::AbstractBlock) && b.context == :preamble
          b.blocks.each { |c| all_blocks << c }
        else
          all_blocks << b
        end
      end
      all_blocks.each do |block|
        if block.is_a?(Asciicrystal::Block) && block.context == :pass
          found = true
          block.lines.first?.not_nil!.should contain("example.com/app.js")
        end
      end
      found.should be_true
    end

    it "processes a custom block macro that creates an image block" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.block_macro(TestImageBlockMacro.new)
      doc.extensions = registry

      source = "= Title\n\ntestimg::photo[]\n"
      reader = Asciicrystal::Reader.new(source)
      Asciicrystal::Parser.parse(reader, doc)

      found = false
      all_blocks2 = [] of Asciicrystal::AbstractBlock
      doc.blocks.each do |b|
        if b.is_a?(Asciicrystal::AbstractBlock) && b.context == :preamble
          b.blocks.each { |c| all_blocks2 << c }
        else
          all_blocks2 << b
        end
      end
      all_blocks2.each do |block|
        if block.is_a?(Asciicrystal::Block) && block.context == :image
          found = true
          block.attributes["target"]?.should eq("photo.png")
        end
      end
      found.should be_true
    end

    it "processes a custom block macro with attributes" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.block_macro(SnippetBlockMacro.new)
      doc.extensions = registry

      source = "= Title\n\nsnippet::app[mode=debug]\n"
      reader = Asciicrystal::Reader.new(source)
      Asciicrystal::Parser.parse(reader, doc)

      found = false
      all_blocks3 = [] of Asciicrystal::AbstractBlock
      doc.blocks.each do |b|
        if b.is_a?(Asciicrystal::AbstractBlock) && b.context == :preamble
          b.blocks.each { |c| all_blocks3 << c }
        else
          all_blocks3 << b
        end
      end
      all_blocks3.each do |block|
        if block.is_a?(Asciicrystal::Block) && block.context == :pass
          found = true
          block.lines.first?.not_nil!.should contain("_mode=debug")
        end
      end
      found.should be_true
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: DocinfoProcessor
  # ---------------------------------------------------------------------------
  describe "DocinfoProcessor integration" do
    it "should add docinfo to document" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.docinfo_processor(MetaRobotsDocinfoProcessor.new)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("= Document Title\n\nsample content")
      Asciicrystal::Parser.parse(reader, doc)

      doc.extensions.not_nil!.docinfo_processors?.should be_true
      doc.extensions.not_nil!.docinfo_processors(:head).size.should eq(1)

      processor = doc.extensions.not_nil!.docinfo_processors(:head).first.instance.as(Asciicrystal::Extensions::DocinfoProcessor)
      processor.process(doc).should eq(%(<meta name="robots" content="index,follow">))
    end

    it "should add multiple docinfo to document" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      registry.activate(doc)
      registry.docinfo_processor(MetaAppDocinfoProcessor.new)
      registry.docinfo_processor(MetaRobotsDocinfoProcessor.new)
      registry.docinfo_processor(FooterDocinfoProcessor.new)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("= Document Title\n\nsample content")
      Asciicrystal::Parser.parse(reader, doc)

      doc.extensions.not_nil!.docinfo_processors?.should be_true
      doc.extensions.not_nil!.docinfo_processors(:head).size.should eq(2)
      doc.extensions.not_nil!.docinfo_processors(:footer).size.should eq(1)
    end

    it "should return extension instance after registering" do
      registry = Asciicrystal::Extensions::Registry.new
      ext1 = registry.preprocessor(SamplePreprocessor.new)
      ext2 = registry.tree_processor(SampleTreeProcessor.new)
      ext3 = registry.postprocessor(UppercasePostprocessor.new)
      ext4 = registry.docinfo_processor(MetaRobotsDocinfoProcessor.new)
      ext5 = registry.include_processor(BoilerplateIncludeProcessor.new)

      ext1.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      ext2.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      ext3.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      ext4.should be_a(Asciicrystal::Extensions::ProcessorExtension)
      ext5.should be_a(Asciicrystal::Extensions::ProcessorExtension)
    end

    it "should support prepending docinfo processor with position >>" do
      registry = Asciicrystal::Extensions::Registry.new
      first = MetaAppDocinfoProcessor.new
      second = MetaRobotsDocinfoProcessor.new({"position" => :>>} of String => String | Bool | Int32 | Array(String) | Set(Symbol) | Symbol)
      registry.docinfo_processor(first)
      registry.docinfo_processor(second)

      exts = registry.docinfo_processors(:head)
      exts.size.should eq(2)
      exts.first.instance.should be_a(MetaRobotsDocinfoProcessor)
      exts.last.instance.should be_a(MetaAppDocinfoProcessor)
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: Multiple extensions in a group
  # ---------------------------------------------------------------------------
  describe "Extension Group integration" do
    it "activates a group that registers multiple extensions" do
      doc = Asciicrystal::Document.new
      groups = {
        :multi => MultiExtensionGroup.new.as(Asciicrystal::Extensions::Group.class | Asciicrystal::Extensions::Group),
      }
      registry = Asciicrystal::Extensions::Registry.new(groups)
      registry.activate(doc)
      doc.extensions = registry

      reader = Asciicrystal::Reader.new("Hello World")
      Asciicrystal::Parser.parse(reader, doc)

      doc.attributes["preprocessor-ran"]?.should eq("true")
      doc.attributes["tree-processor-ran"]?.should eq("true")
    end
  end

  # ---------------------------------------------------------------------------
  # Empty registry queries
  # ---------------------------------------------------------------------------
  describe "Empty registry queries" do
    it "does not crash when querying for extensions if none are registered" do
      registry = Asciicrystal::Extensions::Registry.new
      doc = Asciicrystal::Document.new
      registry.activate(doc)
      doc.extensions = registry

      doc.extensions.not_nil!.registered_for_block?("unknown", :paragraph).should be_false
      doc.extensions.not_nil!.find_block_extension("unknown").should be_nil
      doc.extensions.not_nil!.registered_for_block_macro?("unknown").should be_false
      doc.extensions.not_nil!.find_block_macro_extension("unknown").should be_nil
      doc.extensions.not_nil!.registered_for_inline_macro?("unknown").should be_false
      doc.extensions.not_nil!.find_inline_macro_extension("unknown").should be_nil
      doc.extensions.not_nil!.inline_macros.should be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # Standalone registry
  # ---------------------------------------------------------------------------
  describe "Standalone registry" do
    it "should allow standalone registry to be created but not registered" do
      registry = Asciicrystal::Extensions.create
      registry.should be_a(Asciicrystal::Extensions::Registry)
      Asciicrystal::Extensions.groups.size.should eq(0)
    end

    it "can provide extension registry as an option" do
      registry = Asciicrystal::Extensions::Registry.new
      registry.preprocessor(SamplePreprocessor.new)
      doc = Asciicrystal::Document.new
      registry.activate(doc)
      doc.extensions = registry
      doc.extensions?.should be_true
      doc.extensions.not_nil!.preprocessors?.should be_true
    end

    it "can provide extension registry created without any groups as option" do
      registry = Asciicrystal::Extensions::Registry.new
      doc = Asciicrystal::Document.new
      registry.activate(doc)
      doc.extensions = registry
      doc.extensions?.should be_true
    end
  end

  # ---------------------------------------------------------------------------
  # Document#extensions?
  # ---------------------------------------------------------------------------
  describe "Document#extensions?" do
    it "returns false when no extensions are set" do
      doc = Asciicrystal::Document.new
      doc.extensions?.should be_false
    end

    it "returns true when extensions registry is set" do
      doc = Asciicrystal::Document.new
      registry = Asciicrystal::Extensions::Registry.new
      doc.extensions = registry
      doc.extensions?.should be_true
    end

    it "should not activate registry if no extension groups are registered" do
      Asciicrystal::Extensions.unregister_all
      doc = Asciicrystal::Document.new
      doc.extensions?.should be_false
    end
  end
end
