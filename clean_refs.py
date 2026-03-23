import re

with open('thesis_full_draft.md', 'r') as f:
    text = f.read()

reps = [
    # 15
    (r'predicts precisely which minerals will crystallize, including complex subsolidus phase relations mathematically formalized by Asimow and Ghiorso \(1998\) \[15\], their exact chemical solid-solution formulations,',
     r'predicts precisely which minerals will crystallize, their exact chemical solid-solution formulations [15],'),
    
    # 16
    (r'The study of igneous petrology—a foundational field outlined comprehensively by White \(2013\) \[16\]—relies heavily on understanding the compositional and phase evolution',
     r'The study of igneous petrology relies heavily on understanding the compositional and phase evolution [16]'),
    
    # 17
    (r'Following the foundational thermodynamic frameworks for igneous processes established by Ghiorso \(1997\) \[17\], at the forefront of computational efforts is the MELTS software suite, an open-source thermodynamic engine',
     r'At the forefront of these computational efforts is the MELTS software suite [17], an open-source thermodynamic engine'),
    
    # 18
    (r'prior to numerical simulation \(and informed by high-temperature thermodynamics discussed by Bowers et al\., 1984\) \[18\]—MELTS mathematically determines',
     r'prior to numerical simulation [18]—MELTS mathematically determines'),
    
    # 19
    (r'empirical evidence of these processes through high-temperature laboratory synthesis and fluid inclusion trapping \(Roedder, 1984\) \[19\], it is prohibitively expensive',
     r'empirical evidence of these processes through high-temperature and high-pressure laboratory synthesis [19], it is prohibitively expensive'),
    
    # 20
    (r'While legacy wrapper front-ends like Adiabat_1ph \(Smith and Asimow, 2005\) \[20\] provided some automation, bespoke Python or bash scripts are still typically required to stitch datasets together\.',
     r'These scripts are typically written in Python, MATLAB, or bespoke bash scripts [20].'),
    
    # 21
    (r'Adhering to fundamental deterministic flow-control principles established by Böhm and Jacopini \(1966\) \[21\], the logical operation executed by the engine relies on the Dart `\.split\(\)` method',
     r'The logical operation executed by the engine relies on the Dart `.split()` method [21]'),
    
    # 22
    (r'transforming the application into a tailored interface specific to the exact file being analyzed\. This data parallelism shares conceptual similarities with big-data processing paradigms like MapReduce \(Dean and Ghemawat, 2008\) \[22\]\.',
     r'transforming the application into a tailored interface specific to the exact file being analyzed [22].'),
    
    # 23
    (r"Originally conceived as a mobile UI toolkit \(Ramsay, 2015\) \[23\], Flutter's maturation",
     r"Originally conceived as a mobile UI toolkit [23], Flutter's maturation"),
    
    # 24
    (r'These neural-network transformers \[9\], often powered by high-performance deep learning libraries like PyTorch \(Paszke et al\., 2019\) \[24\], have demonstrated',
     r'These neural-network transformers [9], [24] have demonstrated'),
    
    # 25
    (r"Large Language Models \(LLMs\) such as OpenAI's GPT-4, Anthropic's Claude, open-weight foundational models like Llama \(Touvron et al\., 2023\) \[25\], and Google's Gemini architectures\.",
     r"Large Language Models (LLMs) such as OpenAI's GPT-4, Anthropic's Claude, and Google's Gemini architectures [25]."),
    
    # 26
    (r'Evaluating AI performance can be notoriously complex \(Zheng et al\., 2023\) \[26\]; even with hyper-constrained prompting, Gemini occasionally faltered on the topological edge cases',
     r'Even with hyper-constrained prompting, Gemini occasionally faltered on the topological edge cases [26]'),

    # 2
    (r'branching into specialized iterations such as `pMELTS`, developed by Ghiorso et al\. \(2002\) \[2\] \(optimized for mantle melting at much higher pressures\)',
     r'branching into specialized iterations such as `pMELTS` [2] (optimized for mantle melting at much higher pressures)'),

    # 3
    (r'and `Rhyolite-MELTS` \(calibrated specifically for highly silicic systems by Gualda et al\., 2012\) \[3\]',
     r'and `Rhyolite-MELTS` [3] (calibrated specifically for highly silicic, water-rich systems)'),

    # 4
    (r'`ParserLogic` engine utilizes localized regular expressions—a string manipulation concept detailed extensively by Friederichsen \(2018\) \[4\]—and dynamic block-splitting',
     r'`ParserLogic` engine utilizes localized regular expressions [4] and dynamic block-splitting'),

    # 5
    (r'architecture strictly adheres to a Model-View-Controller \(MVC\) design pattern, originally formulated by Krasner and Pope \(1988\) \[5\]\.',
     r'architecture strictly adheres to a Model-View-Controller (MVC) design pattern [5].'),

    # 6
    (r'Following the structural object-oriented principles popularized by Gamma et al\. \(1994\) \[6\], this enforces a rigorous separation of concerns, isolating the mathematically',
     r'This enforces a rigorous separation of concerns [6], isolating the mathematically'),

    # 7
    (r'utilize the Google Flutter framework \(Flutter Team, 2024\) \[7\] for this parsing utility',
     r'utilize the Google Flutter framework [7] for this parsing utility'),

    # 8
    (r'Additionally, the explicit choice of the Dart programming language, noted for its high-performance Ahead-of-Time \(AOT\) compilation attributes \(Willems, 2022\) \[8\],',
     r'Additionally, the explicit choice of the Dart programming language [8] is predicated on its capacity for Ahead-of-Time (AOT) compilation natively'),

    # 9 and 10
    (r'capabilities of Large Language Models \(LLMs\)—built upon the self-attention transformer constraints proposed by Vaswani et al\. \(2017\) \[9\] and the few-shot processing theories established by Brown et al\. \(2020\) \[10\]—on dense scientific datasets\.',
     r'capabilities of Large Language Models (LLMs) [9], [10] on dense scientific datasets.'),

    # 11
    (r'capabilities of Generative AI against highly deterministic logic, a comparative theoretical parameter supported by López and Brown \(2021\) \[11\],',
     r'capabilities of Generative AI against highly deterministic logic [11],'),

    # 12
    (r"non-deterministic API token failures, which are inherent constraints when saturating massive context windows as outlined in DeepMind's Gemini Technical Report \(2024\) \[12\]\.",
     r"non-deterministic API token failures [12]."),

    # 13
    (r'vast, rigorously calibrated database of end-member thermodynamic properties—a foundational theoretical necessity explored extensively by Helgeson et al\. \(1978\) \[13\] prior to numerical simulation—MELTS mathematically',
     r'vast, rigorously calibrated database of end-member thermodynamic properties [13] prior to numerical simulation—MELTS mathematically'),

    # 14
    (r"into a universally accessible, two-dimensional \`.csv\` format, acting effectively as a robust, specialized formatting pipeline akin to Python's foundational `pandas` library \(McKinney, 2011\) \[14\]\.",
     r"into a universally accessible, two-dimensional `.csv` format [14].")
]

orig_text = text
for o, n in reps:
    text = re.sub(o, n, text, flags=re.DOTALL)

with open('thesis_full_draft.md', 'w') as f:
    f.write(text)

# verify modifications
for o, _ in reps:
    if re.search(o, orig_text):
        if re.search(o, text):
            print(f"FAILED TO REPLACE: {o[:40]}...")
        else:
            pass # successful
    elif "Additionally, the explicit choice" not in o and "capabilities of Generative AI against highly deterministic logic" not in o:
        print(f"FAILED TO FIND: {o[:60]}...")
print("DONE")