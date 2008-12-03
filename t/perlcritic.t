#!perl

if (!require Test::Perl::Critic) {
    Test::More::plan(
        skip_all => "Test::Perl::Critic required for testing PBP compliance"
    );
}
else {
    import Test::Perl::Critic;
}

Test::Perl::Critic::all_critic_ok();
