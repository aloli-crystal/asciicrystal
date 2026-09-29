require "../spec_helper"

# Une sous-classe de Hash, comme `Marten::Routing::MatchParameters`. Sa seule
# présence dans le programme faisait planter le compilateur Crystal 1.19 au
# codegen de `Parser#next_section` (voir
# doc/crystal-bug-hash-virtual-downcast.md). Elle est déclarée au niveau
# supérieur : c'est la compilation même de la suite qui sert de garde-fou,
# l'exemple ci-dessous vérifiant en plus qu'un document se convertit.
class HashSubclassSpecParams < Hash(String, Int32 | String | Nil)
end

describe "A program defining a Hash subclass" do
  it "loads and converts a document with nested sections" do
    params = HashSubclassSpecParams.new
    params["id"] = 1
    params.size.should eq(1)

    source = <<-ADOC
      = Titre

      Préambule.

      == Section

      === Suite

      * un
      * deux

      [cols="1a,1"]
      |===
      | _cellule_ | b
      |===
      ADOC
    doc = Asciicrystal.load(source, {"safe" => "secure"})
    doc.should be_a(Asciicrystal::Document)
    html = doc.convert || ""
    html.should contain(%(<h2 id="_section">Section</h2>))
    html.should contain(%(<h3 id="_suite">Suite</h3>))
    html.should contain("<li>")
    html.should contain("<em>cellule</em>")
  end
end
