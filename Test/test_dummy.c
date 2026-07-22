#ifdef TEST

#include <stdint.h>

void setUp ( void ){
    //TODO    
}

void tearDown ( void ){
    //TODO
}


void dummy_test_to_check_github_actions ( void ){
    uint8_t a = 10;

    TEST_ASSERT_EQUAL ( 10, a );
}


#endif /* TEST */