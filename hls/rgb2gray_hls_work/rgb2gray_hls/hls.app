<AutoPilot:project xmlns:AutoPilot="com.autoesl.autopilot.project" projectType="C/C++" name="rgb2gray_hls" ideType="classic" top="rgb2gray_top">
    <files>
        <file name="../rgb2gray_kernel.cpp" sc="0" tb="false" cflags="--std=c++14" csimflags="" blackbox="false"/>
        <file name="../../../tb_rgb2gray.cpp" sc="0" tb="1" cflags="--std=c++14 -Wno-unknown-pragmas" csimflags="" blackbox="false"/>
    </files>
    <Simulation argv="">
        <SimFlow name="csim" setup="false" optimizeCompile="false" clean="true" ldflags="" mflags=""/>
    </Simulation>
    <solutions>
        <solution name="solution" status=""/>
    </solutions>
</AutoPilot:project>

